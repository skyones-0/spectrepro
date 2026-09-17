# Spectre Pro — UML de arquitectura

Estos diagramas describen la arquitectura actual de la aplicación macOS según los módulos de `macos/Sources`.

## Componentes principales

```mermaid
flowchart TB
    App["SpectrePro.App\nSwiftUI + AppKit"]
    Delegate["SpectreProDelegate\nventanas y lifecycle"]
    Surface["SurfaceView\nterminal surface"]
    Core["SpectreProKit / Zig core\nrendering, input, config"]
    Sidebar["SidebarHubView\nQuick Commands / Sessions"]
    Settings["SettingsView\nconfiguración"]
    Runtime["SessionRuntimeRegistry\nRemoteSessionRuntime por surface"]
    SSH["SessionManagerView\nSSHProcessSpec"]
    SFTP["SFTPBrowserView\nSSHTransferManager"]
    Automation["AutomationExecutor\nExpectSendEngine"]
    Logger["SessionLogger\nlogs por sesión"]
    Yubi["YubiKeyAuthenticationCoordinator\nPIN / touch / agent"]
    Workspace["WorkspaceStore\ntabs, splits, timeline"]
    Update["UpdateController + Sparkle\nappcast / update"]
    Keychain["SessionCredentialStore\nmacOS Keychain"]
    Remote[("SSH host / SFTP server")]
    Release[("GitHub Releases\nDMG + appcast")]

    App --> Delegate
    App --> Surface
    App --> Sidebar
    App --> Settings
    Surface --> Core
    Sidebar --> SSH
    Sidebar --> Workspace
    SSH --> Runtime
    Runtime --> Automation
    Runtime --> Logger
    Runtime --> Yubi
    Runtime --> SFTP
    Runtime --> Keychain
    SSH --> Remote
    SFTP --> Remote
    Automation --> Remote
    Update --> Release
    Settings --> Core
```

## Modelo de clases de sesión

```mermaid
classDiagram
    class SessionRuntimeRegistry {
        +shared
        +runtime(surfaceID) RemoteSessionRuntime
        +remove(surfaceID)
        +activeSurfaceIDs Set~UUID~
    }

    class RemoteSessionRuntime {
        +surfaceID UUID
        +session SavedSession?
        +logger SessionLogger
        +automation ExpectSendEngine
        +transfers SSHTransferManager
        +reconnect SSHReconnectController
        +yubikey YubiKeyAuthenticationCoordinator
        +attach(session)
        +prepareAuthentication(session) String?
        +reset()
    }

    class SavedSession {
        +id UUID
        +name String
        +host String
        +user String
        +port Int?
        +sessionType String
        +sshAuthentication SSHAuthenticationMethod
        +buildProcessSpec(identityAgentPath) SSHProcessSpec
    }

    class SSHTransferManager {
        +registerContext(surfaceID, session)
        +enqueue(transfer)
        +cancel(transferID)
        +reset(surfaceID)
    }

    class SessionLogger {
        +startRecording(sessionName)
        +log(text)
        +stopRecording() URL?
        +ingestScreenText(text)
    }

    class YubiKeyAuthenticationCoordinator {
        +state YubiKeyAuthenticationState
        +prepare(session)
        +identityAgentPath String?
        +acceptPIN(pin)
        +cancelPIN()
        +stop()
    }

    SessionRuntimeRegistry "1" o-- "many" RemoteSessionRuntime
    RemoteSessionRuntime *-- SessionLogger
    RemoteSessionRuntime *-- ExpectSendEngine
    RemoteSessionRuntime *-- SSHTransferManager
    RemoteSessionRuntime *-- SSHReconnectController
    RemoteSessionRuntime *-- YubiKeyAuthenticationCoordinator
    RemoteSessionRuntime --> SavedSession
    SSHTransferManager --> SavedSession

    class ExpectSendEngine
    class SSHReconnectController
    SSHTransferManager --> SSHReconnectController
    ExpectSendEngine --> SavedSession
```

## Conexión SSH con YubiKey PIV

```mermaid
sequenceDiagram
    actor User
    participant Sidebar as SessionManagerView
    participant Runtime as RemoteSessionRuntime
    participant Auth as YubiKeyAuthenticationCoordinator
    participant Helper as SpectreProYubiKeyAgent
    participant Agent as SSH_AUTH_SOCK
    participant SSH as /usr/bin/ssh
    participant Host as SSH host

    User->>Sidebar: Ejecuta sesión YubiKey PIV
    Sidebar->>Runtime: prepareAuthentication(session)
    Runtime->>Auth: prepare(session)
    Auth->>Auth: Detecta PKCS#11 y claves PIV
    Auth->>Helper: Inicia helper firmado
    Helper-->>Auth: Publica clave PIV y socket
    Auth-->>Runtime: identityAgentPath
    Runtime-->>Sidebar: Ruta del agente por sesión
    Sidebar->>SSH: Ejecuta con IdentityAgent + SSH_AUTH_SOCK
    SSH->>Agent: Solicita firma ECDSA PIV
    Agent->>Helper: Solicita PIN
    Helper-->>Auth: PIN requerido
    Auth-->>User: Muestra PIN en sidebar
    User->>Auth: Introduce PIN
    Auth-->>Helper: Envía PIN temporal
    Helper-->>User: Solicita tocar YubiKey
    User->>Helper: Toca YubiKey
    Helper-->>Agent: Firma desafío SSH
    Agent-->>SSH: Firma válida
    SSH->>Host: Autenticación pública
    Host-->>SSH: Sesión aceptada
    SSH-->>Sidebar: Terminal conectada
```

## Estados de autenticación YubiKey

```mermaid
stateDiagram-v2
    [*] --> idle
    idle --> detecting: prepare(session)
    detecting --> authenticating: helper iniciado
    detecting --> failed: provider ausente
    authenticating --> waitingForPIN: helper solicita PIN
    waitingForPIN --> waitingForTouch: PIN aceptado
    waitingForPIN --> failed: cancelar / timeout
    waitingForTouch --> authenticating: firma en progreso
    authenticating --> authenticated: firma confirmada
    authenticating --> failed: helper / token removido
    authenticated --> idle: stop / reset
    failed --> idle: retry / reset
```

## Flujo SFTP y transferencias

```mermaid
sequenceDiagram
    actor User
    participant Browser as SFTPBrowserView
    participant Client as SFTPClient
    participant Manager as SSHTransferManager
    participant Graph as SFTPTransferGraphView
    participant Host as SFTP server

    User->>Browser: Abre SFTP de una sesión SSH
    Browser->>Client: list(path)
    Client->>Host: Solicita directorio
    Host-->>Client: Entradas SFTP
    Client-->>Browser: SFTPDirectoryEntry[]
    User->>Browser: Inicia upload/download
    Browser->>Manager: enqueue(transfer)
    Manager->>Client: Ejecuta transferencia asíncrona
    Client->>Host: Transfiere bloques
    Host-->>Client: Bytes enviados / recibidos
    Client-->>Manager: SFTPTransferProgress
    Manager-->>Graph: velocidad, bytes, porcentaje
    Graph-->>User: progreso y gráfica suavizada
    Manager-->>Browser: completado / error / cancelado
```

## Actualizaciones de la aplicación

```mermaid
flowchart LR
    Launch["Inicio de Spectre Pro"] --> Service["UpdateController\ncomprobación en segundo plano"]
    Service --> Appcast["Sparkle appcast.xml"]
    Appcast --> Compare{"¿Hay versión nueva?"}
    Compare -->|No| Idle["Continúa sin bloquear el inicio"]
    Compare -->|Sí| Badge["UpdateBadge / UpdatePill"]
    Badge --> Confirm["Usuario confirma actualización"]
    Confirm --> Download["Descarga DMG / ZIP firmado"]
    Download --> Verify["Sparkle valida firma y metadatos"]
    Verify --> Install["Instala y reinicia según confirmación"]
    Verify --> Error["Muestra error y conserva versión actual"]
    Install --> Launch
```

## CI/CD y publicación

```mermaid
flowchart TD
    Change["Cambio en código"] --> PR["Pull Request"]
    PR --> CI["macOS CI\ncompilación y pruebas"]
    PR --> Security["CodeQL / dependency review"]
    PR --> Quality["lint / branding / benchmarks"]
    CI --> Merge{"¿Checks correctos?"}
    Security --> Merge
    Quality --> Merge
    Merge -->|Sí| Main["main"]
    Main --> Version["Actualizar VERSION"]
    Version --> SignedCommit["Commit firmado con YubiKey"]
    SignedCommit --> SignedTag["Tag firmado vX.Y.Z"]
    SignedTag --> Release["Personal macOS Release"]
    Release --> Build["Build app + helper YubiKey"]
    Build --> Sign["Firma macOS + Sparkle"]
    Sign --> Attest["SHA-256 + SBOM + attestation"]
    Attest --> GitHub["GitHub Release + appcast.xml"]
    GitHub --> Update["Spectre Pro detecta actualización"]
```

