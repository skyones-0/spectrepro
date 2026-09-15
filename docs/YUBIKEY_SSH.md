# YubiKey SSH authentication

Spectre Pro delegates SSH authentication to the OpenSSH client installed on macOS. The app stores only the selected authentication mode and provider path; PINs, passphrases, and private key material remain outside the session file.

## PIV / PKCS#11

PIV is supported through Yubico's `libykcs11.dylib` module. Spectre Pro checks these locations when you choose **Detect** in the session editor:

```text
/opt/homebrew/lib/libykcs11.dylib
/usr/local/lib/libykcs11.dylib
/Library/Application Support/Yubico/libykcs11.dylib
```

The detector also verifies the module architecture and enumerates the public keys exposed by the YubiKey with:

```sh
ssh-keygen -D /path/to/libykcs11.dylib
```

The selected session connects with OpenSSH's `-I` option. The PIV PIN prompt is owned by OpenSSH and is never persisted by Spectre Pro. The same provider is passed to SCP and SFTP transfers.

## FIDO2 security keys

FIDO2 SSH keys use an OpenSSH key handle such as:

```text
~/.ssh/id_ed25519_sk
~/.ssh/id_ecdsa_sk
```

The handle file is not the private key. The private key remains on the YubiKey and OpenSSH requests a touch, and optionally a PIN, for signing.

The OpenSSH client must report `sk-` key types:

```sh
ssh -Q key | grep '^sk-'
```

The macOS-provided OpenSSH may not include FIDO support. Install a FIDO-capable OpenSSH build and place it ahead of `/usr/bin` on `PATH` when using FIDO2 keys.

## Performance and privacy

YubiKey detection is not part of app startup. It runs only after the user presses **Detect**, at utility priority, and performs short-lived local checks. Spectre Pro does not poll the USB device, load the PKCS#11 module at launch, or write authentication prompts to session logs.

## Troubleshooting

- **No PIV keys detected:** confirm the YubiKey is connected and that a certificate is loaded in a PIV slot.
- **FIDO2 unavailable:** install an OpenSSH build compiled with FIDO support and run detection again.
- **Authentication denied:** confirm the corresponding public key is present in the server's `authorized_keys` and inspect the SSH error output.
- **Provider path rejected:** choose a readable, architecture-compatible `libykcs11.dylib`; do not enter a shell command in the path field.

See Yubico's guides for [PIV with PKCS#11](https://developers.yubico.com/PIV/Guides/SSH_with_PIV_and_PKCS11.html) and [FIDO2 SSH](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html).
