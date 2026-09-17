package main

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/rsa"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"github.com/go-piv/piv-go/piv"
	"golang.org/x/crypto/ssh"
	"golang.org/x/crypto/ssh/agent"
)

var version = "development"

type promptMessage struct {
	Type    string `json:"type"`
	Serial  uint32 `json:"serial,omitempty"`
	Retries int    `json:"retries,omitempty"`
	Token   string `json:"token"`
	PIN     string `json:"pin,omitempty"`
	Error   string `json:"error,omitempty"`
}

type promptClient struct {
	path  string
	token string
}

func (p promptClient) getPIN(serial uint32, retries int) (string, error) {
	conn, err := net.DialTimeout("unix", p.path, 10*time.Second)
	if err != nil { return "", fmt.Errorf("connect to Spectre Pro PIN panel: %w", err) }
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(90 * time.Second))
	request := promptMessage{Type: "pin", Serial: serial, Retries: retries, Token: p.token}
	encoded, err := json.Marshal(request)
	if err != nil { return "", err }
	encoded = append(encoded, '\n')
	if _, err := conn.Write(encoded); err != nil { return "", err }
	response, err := io.ReadAll(conn)
	if err != nil { return "", err }
	var message promptMessage
	if err := json.Unmarshal(bytes.TrimSpace(response), &message); err != nil { return "", err }
	if message.Token != p.token { return "", errors.New("invalid Spectre Pro authentication token") }
	if message.Error != "" { return "", errors.New(message.Error) }
	if message.PIN == "" { return "", errors.New("empty PIN") }
	return message.PIN, nil
}

type pivAgent struct {
	mu          sync.Mutex
	yubiKey     *piv.YubiKey
	serial      uint32
	prompt      promptClient
	touchTimer  *time.Timer
}

func (a *pivAgent) ensureKey() error {
	if a.yubiKey != nil {
		if _, err := a.yubiKey.AttestationCertificate(); err == nil { return nil }
		a.yubiKey.Close()
		a.yubiKey = nil
	}
	cards, err := piv.Cards()
	if err != nil { return err }
	for _, card := range cards {
		key, openErr := piv.Open(card)
		if openErr == nil {
			a.yubiKey = key
			a.serial, _ = key.Serial()
			return nil
		}
	}
	return errors.New("no YubiKey detected")
}

func publicKey(key *piv.YubiKey) (ssh.PublicKey, error) {
	certificate, err := key.Certificate(piv.SlotAuthentication)
	if err != nil { return nil, err }
	switch certificate.PublicKey.(type) {
	case *ecdsa.PublicKey, *rsa.PublicKey:
	default: return nil, fmt.Errorf("unsupported PIV public key type %T", certificate.PublicKey)
	}
	return ssh.NewPublicKey(certificate.PublicKey)
}

func (a *pivAgent) signer() (ssh.Signer, error) {
	if err := a.ensureKey(); err != nil { return nil, err }
	key, err := publicKey(a.yubiKey)
	if err != nil { return nil, err }
	privateKey, err := a.yubiKey.PrivateKey(piv.SlotAuthentication, key.(ssh.CryptoPublicKey).CryptoPublicKey(), piv.KeyAuth{
		PINPrompt: func() (string, error) {
			retries, _ := a.yubiKey.Retries()
			return a.prompt.getPIN(a.serial, retries)
		},
	})
	if err != nil { return nil, err }
	return ssh.NewSignerFromKey(privateKey)
}

func (a *pivAgent) List() ([]*agent.Key, error) {
	a.mu.Lock(); defer a.mu.Unlock()
	if err := a.ensureKey(); err != nil { return nil, err }
	key, err := publicKey(a.yubiKey)
	if err != nil { return nil, err }
	return []*agent.Key{{Format: key.Type(), Blob: key.Marshal(), Comment: fmt.Sprintf("Spectre Pro YubiKey #%d PIV Slot 9a", a.serial)}}, nil
}

func (a *pivAgent) Sign(key ssh.PublicKey, data []byte) (*ssh.Signature, error) {
	return a.SignWithFlags(key, data, 0)
}

func (a *pivAgent) Signers() ([]ssh.Signer, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	signer, err := a.signer()
	if err != nil { return nil, err }
	return []ssh.Signer{signer}, nil
}

func (a *pivAgent) SignWithFlags(key ssh.PublicKey, data []byte, flags agent.SignatureFlags) (*ssh.Signature, error) {
	a.mu.Lock(); defer a.mu.Unlock()
	signer, err := a.signer()
	if err != nil { return nil, err }
	if !bytes.Equal(signer.PublicKey().Marshal(), key.Marshal()) { return nil, errors.New("requested key is not present on the YubiKey") }
	if a.touchTimer != nil { a.touchTimer.Stop() }
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	a.touchTimer = time.AfterFunc(5*time.Second, func() { _ = ctx })
	algorithm := key.Type()
	if algorithm == ssh.KeyAlgoRSA && flags&agent.SignatureFlagRsaSha256 != 0 { algorithm = ssh.SigAlgoRSASHA2256 }
	if algorithm == ssh.KeyAlgoRSA && flags&agent.SignatureFlagRsaSha512 != 0 { algorithm = ssh.SigAlgoRSASHA2512 }
	return signer.(ssh.AlgorithmSigner).SignWithAlgorithm(rand.Reader, data, algorithm)
}

func (a *pivAgent) Add(agent.AddedKey) error { return errors.New("adding keys is unsupported") }
func (a *pivAgent) Remove(ssh.PublicKey) error { return errors.New("removing keys is unsupported") }
func (a *pivAgent) RemoveAll() error { return a.Close() }
func (a *pivAgent) Lock([]byte) error { return errors.New("locking is unsupported") }
func (a *pivAgent) Unlock([]byte) error { return errors.New("unlocking is unsupported") }
func (a *pivAgent) Extension(string, []byte) ([]byte, error) { return nil, agent.ErrExtensionUnsupported }
func (a *pivAgent) Close() error {
	a.mu.Lock(); defer a.mu.Unlock()
	if a.yubiKey != nil { err := a.yubiKey.Close(); a.yubiKey = nil; return err }
	return nil
}

func main() {
	listenPath := flag.String("l", "", "SSH agent UNIX socket")
	promptPath := flag.String("p", "", "Spectre Pro PIN UNIX socket")
	token := flag.String("t", "", "per-session authentication token")
	flag.Parse()
	if *listenPath == "" || *promptPath == "" || *token == "" { os.Exit(2) }
	_ = os.Remove(*listenPath)
	if err := os.MkdirAll(filepath.Dir(*listenPath), 0700); err != nil { os.Exit(1) }
	listener, err := net.Listen("unix", *listenPath)
	if err != nil { os.Exit(1) }
	defer listener.Close()
	_ = os.Chmod(*listenPath, 0600)
	agentServer := &pivAgent{prompt: promptClient{path: *promptPath, token: *token}}
	defer agentServer.Close()
	for {
		connection, acceptErr := listener.Accept()
		if acceptErr != nil {
			if errors.Is(acceptErr, syscall.EINTR) { continue }
			return
		}
		go func() { defer connection.Close(); _ = agent.ServeAgent(agentServer, connection) }()
	}
}
