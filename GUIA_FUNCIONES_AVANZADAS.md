# Manual Técnico y Guía Avanzada de Spectre Pro

Este manual proporciona una referencia técnica exhaustiva de todas las capacidades avanzadas de **Spectre Pro**, diseñada para ingenieros de confiabilidad de sitios (SRE), arquitectos de infraestructura, administradores de sistemas y desarrolladores senior.

---

## Índice General

1. [Arquitectura del Núcleo y Aislamiento de Runtimes](#1-arquitectura-del-núcleo-y-aislamiento-de-runtimes)
2. [Session Manager & Topologías de Red Avanzadas](#2-session-manager--topologías-de-red-avanzadas)
   - 2.1 Modelo de Seguridad y Credenciales en macOS Keychain
   - 2.2 Configuración de Bastion / Jump Hosts (Multi-Hop)
   - 2.3 Túneles SSH Locales (`-L`) y Remotos (`-R`)
   - 2.4 Importación y Mapeo de Inventarios (Ansible, SSH Config, Schema v2)
3. [SFTP Browser, SCP y Multiplexación Zero-Handshake](#3-sftp-browser-scp-y-multiplexación-zero-handshake)
   - 3.1 Arquitectura de Multiplexación ControlMaster
   - 3.2 Flujo de Trabajo con el Navegador Gráfico SFTP
   - 3.3 Transferencias Rápidas: Atajos, Drag & Drop y Descarga Contextual
   - 3.4 Motor de Cola Persistente y Algoritmo de Reintento
4. [Quick Commands & Automatización Dinámica de Terminal](#4-quick-commands--automatización-dinámica-de-terminal)
   - 4.1 Modos de Inyección (`▶ Run` vs `✎ Insert`) y Split & Run
   - 4.2 Interpolación Dinámica de Variables y Tokens de Contexto
   - 4.3 Broadcast Mode: Concurrencia sobre Splits Activos
   - 4.4 Aislamiento de Foco y Máquina de Estados del Teclado
5. [Monitor de Procesos Darwin & Orquestación de Background Jobs](#5-monitor-de-procesos-darwin--orquestación-de-background-jobs)
   - 5.1 Telemetría de CPU en Microsegundos vía `proc_pidinfo`
   - 5.2 Estados Braille y Ventana de Histéresis
   - 5.3 Ciclo de Vida y Terminación de Tareas en Segundo Plano
6. [Resiliencia de Conexión: Reconexión Reactiva y Mitigación MITM](#6-resiliencia-de-conexión-reconexión-reactiva-y-mitigación-mitm)
   - 6.1 Detección de Enlace con `NWPathMonitor`
   - 6.2 Máquina de Estados de Reconexión y Backoff
   - 6.3 Verificación Estricta de Claves de Host y Alerta Toast
7. [Session Logger: Auditoría Forense y Sanitización de Secretos en Vivo](#7-session-logger-auditoría-forense-y-sanitización-de-secretos-en-vivo)
   - 7.1 Captura Real de Pantalla vs Snapshots Sintéticos
   - 7.2 Motor de Redacción Heurística y Reglas de Expresiones Regulares
8. [Automation Hub: Orquestación Declarativa Multi-Host](#8-automation-hub-orquestación-declarativa-multi-host)
   - 8.1 Modelo Declarativo de Planes y Políticas de Aislamiento
   - 8.2 Reglas Expect/Send Vinculadas a Keychain
   - 8.3 Fase de Previsualización Mandatoria y Guardarraíles de Producción
   - 8.4 Análisis del Historial de Ejecución y Auditoría Forense
9. [Workspace Hub: Diagnóstico de Incidentes y Comparador Multi-Host](#9-workspace-hub-diagnóstico-de-incidentes-y-comparador-multi-host)
   - 9.1 Persistencia Atómica del Árbol de Splits y Pestañas
   - 9.2 Timeline Unificado de Incidentes
   - 9.3 Multi-Host Output Clustering y Detección de Anomalías (Outliers)
   - 9.4 Generación y Exportación del Incident Bundle Sanitizado
10. [Fleet Hub: Telemetría de Flota y Salud Operativa](#10-fleet-hub-telemetría-de-flota-y-salud-operativa)
    - 10.1 Pings Asíncronos Paralelos y Medición de Latencia
    - 10.2 Monitoreo de Túneles y Vencimiento de Certificados
11. [Consola Serial: Perfiles de Hardware y Control de Flujo](#11-consola-serial-perfiles-de-hardware-y-control-de-flujo)
    - 11.1 Detección de Controladores USB-Serie en macOS
    - 11.2 Perfiles por Fabricante (Cisco, Juniper, Arista, MikroTik)
    - 11.3 Rate-Limiting Anti-Desbordamiento de FIFO
12. [Casos de Uso Reales de Extremo a Extremo (Runbooks)](#12-casos-de-uso-reales-de-extremo-a-extremo-runbooks)
13. [Referencia Rápida de Atajos de Teclado y Comandos](#13-referencia-rápida-de-atajos-de-teclado-y-comandos)

---

## 1. Arquitectura del Núcleo y Aislamiento de Runtimes

Spectre Pro utiliza una arquitectura híbrida de alto rendimiento:
- **Terminal Core (Zig):** Manejo del PTY, emulación VT100/xterm, decodificación UTF-8, gestión del búfer circular y renderizado acelerado por hardware mediante **Metal**.
- **Application & Orchestration Layer (Swift / AppKit / SwiftUI):** Interfaz nativa, gestión de ventanas, monitor de procesos POSIX, integración con macOS Keychain, subsistema de red y automatizaciones.

### Aislamiento por Superficie (`RemoteSessionRuntime`)

A diferencia de clientes tradicionales donde los túneles y variables se manejan de manera global, Spectre Pro asigna a cada pestaña o split pane un `RemoteSessionRuntime` exclusivo identificado por un `surfaceID` (UUID v4):

```
┌──────────────────────────────────────────────────────────┐
│                      Spectre Pro Window                  │
│  ┌─────────────────────────┐  ┌─────────────────────────┐ │
│  │   Tab 1: Web-Prod-01    │  │   Tab 2: DB-Replica     │ │
│  │ ┌─────────────────────┐ │  │ ┌─────────────────────┐ │ │
│  │ │ RemoteSessionRuntime│ │  │ │ RemoteSessionRuntime│ │ │
│  │ │  - Transfers Queue  │ │  │ │  - Transfers Queue  │ │ │
│  │ │  - ExpectSendEngine │ │  │ │  - ExpectSendEngine │ │ │
│  │ │  - SessionLogger    │ │  │ │  - SessionLogger    │ │ │
│  │ │  - ReconnectEngine  │ │  │ │  - ReconnectEngine  │ │ │
│  │ │  - CredentialStore  │ │  │ │  - CredentialStore  │ │ │
│  │ └─────────────────────┘ │  │ └─────────────────────┘ │ │
│  └─────────────────────────┘  └─────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

**Garantías de aislamiento:**
- **Sin contaminación cruzada:** Si `Tab 1` satura su ancho de banda en una transferencia SCP, no afecta la cola de `Tab 2`.
- **Destrucción limpia:** Al cerrar un tab o reemplazar una superficie, el runtime invoca `reset()`, cancelando procesos en background, liberando descriptores de socket, deteniendo timers y limpiando credenciales temporales en memoria.

---

## 2. Session Manager & Topologías de Red Avanzadas

Acceso: **`⌘⇧S` (`Cmd+Shift+S`)** o desde la barra superior de Spectre Pro.

### 2.1 Modelo de Seguridad y Credenciales en macOS Keychain

Spectre Pro implementa el principio de **cero secretos en texto plano**:
1. Cuando defines una contraseña, passphrase de clave privada o token, se genera un identificador `CredentialReference(id: UUID)`.
2. El secreto se guarda en el servicio protegido `co.skyones.spectrepro.credentials` del Keychain de macOS usando `SecItemAdd`/`SecItemUpdate` con clase `kSecClassGenericPassword` y accesibilidad `kSecAttrAccessibleAfterFirstUnlock`.
3. En disco (`~/Library/Application Support/SpectrePro/sessions.json` o `sessions_envelope.json`), únicamente se almacena el UUID de la referencia.
4. **Limpieza y Duplicación Segura:**
   - **Clonado:** Al duplicar una sesión, el sistema extrae el secreto original del Keychain y genera un nuevo registro independiente en el Keychain (`duplicate(from:)`). Modificar una copia nunca altera la original.
   - **Reconciliación de huérfanos:** La función `reconcileKeychainOrphans()` analiza todas las sesiones activas y purga de forma segura del Keychain cualquier credencial que haya quedado desreferenciada.

### 2.2 Configuración de Bastion / Jump Hosts (Multi-Hop)

Para conectar con máquinas en redes privadas (VPC, DMZ) a través de un servidor intermedio:

1. Abre el **Session Manager** (`⌘⇧S`) y haz clic en **New Session**.
2. En la pestaña **General**, configura el destino final:
   - **Host:** `10.0.1.45`
   - **User:** `ubuntu`
   - **Port:** `22`
3. Ve a la pestaña **Advanced**:
   - Activa el interruptor **Use Jump Host (Bastion)**.
   - **Bastion Host:** `bastion.empresa.com`
   - **Bastion User:** `secops`
   - **Bastion Port:** `22` (o el puerto configurado para SSH expuesto).
   - **Identity Key:** Selecciona la llave privada autorizada para el Bastion.
4. Spectre Pro construye de forma determinista la invocación OpenSSH utilizando `-J secops@bastion.empresa.com:22` o la directiva ProxyJump aislada en subprocesos controlados, evitando inyecciones de comandos.

### 2.3 Túneles SSH Locales (`-L`) y Remotos (`-R`)

Los túneles se gestionan de forma declarativa por sesión:

#### Ejemplo: Túnel Local a Base de Datos PostgreSQL remota
- **Objetivo:** Conectarse desde DBeaver o psql en tu Mac a `localhost:5432` y acceder a la BD en `db-internal.vpc:5432`.
- **Configuración en pestaña Tunnels:**
  - Tipo: **Local Forwarding (-L)**
  - Local Port: `5432`
  - Remote Target Host: `db-internal.vpc`
  - Remote Target Port: `5432`

#### Ejemplo: Túnel Remoto para Reverse Proxy (Webhook debugging)
- **Objetivo:** Exponer un servicio web local que corre en tu Mac en el puerto `3000` para que el servidor remoto lo acceda en `localhost:8080`.
- **Configuración:**
  - Tipo: **Remote Forwarding (-R)**
  - Remote Listen Port: `8080`
  - Local Host: `127.0.0.1`
  - Local Port: `3000`

### 2.4 Importación y Mapeo de Inventarios

Spectre Pro dispone de un motor de ingesta de configuraciones con esquema versionado:
- **Importar `~/.ssh/config`:** Lee bloques `Host`, directivas `HostName`, `User`, `Port`, `IdentityFile` y `ProxyJump`.
- **Importar Ansible (INI y YAML):**
  - Parsea archivos `hosts.ini` con grupos (`[webservers]`, `[databases]`) e inventarios YAML (`all: children: ...`).
  - Mapea variables como `ansible_host`, `ansible_user`, `ansible_port` y `ansible_ssh_private_key_file` automáticamente a objetos `SavedSession`.
- **Exportación Segura:** Exporta el inventario a JSON/YAML respetando la separación de secretos: las credenciales nunca son incluidas en los archivos de exportación.

---

## 3. SFTP Browser, SCP y Multiplexación Zero-Handshake

### 3.1 Arquitectura de Multiplexación ControlMaster

Cuando Spectre Pro conecta una sesión SSH interactiva, registra el contexto en `SSHTransferManager` y habilita sockets UNIX de control (`ControlMaster=auto`, `ControlPath=~/.ssh/spectrepro-%C`):

```
[Terminal Surface] ────> [SSH Interactive Process] ────> (OpenSSH ControlMaster Socket)
                                                                    ▲
[SFTP Browser Modal] ──> [sftp -b - command client] ───────────────┤
                                                                    │
[Drag & Drop / ⌘⇧U] ───> [scp / sftp transfer workers] ─────────────┘
```

**Ventajas clave:**
- **Zero-Handshake:** Abrir el navegador SFTP o transferir un archivo toma menos de **50 milisegundos**, ya que no requiere un nuevo intercambio de claves TLS/SSH ni re-autenticación por contraseña o llave.
- **Sin interferencia en PTY:** Las transferencias ocurren a través de canales secundarios sin inyectar caracteres ni pausar el shell interactivo de la terminal.

### 3.2 Flujo de Trabajo con el Navegador Gráfico SFTP

1. **Abrir el explorador:**
   - Haz **clic derecho** sobre cualquier parte de la terminal de una sesión SSH activa.
   - En el menú contextual, haz clic en **`Open SFTP Browser...`**.
2. **Navegación:**
   - La barra superior muestra la ruta remota activa (por defecto `.`, que corresponde al home del usuario).
   - Escribe cualquier ruta absoluta (ej. `/etc/nginx/sites-available`) y presiona `Enter` o haz clic en **Go**.
   - Haz doble clic en cualquier carpeta de la tabla para entrar en ella.
   - Para subir un nivel, puedes escribir `..` en la barra de ruta.
3. **Subir archivos:**
   - Haz clic en el botón **Upload** (􀁶 en la barra del explorador).
   - Selecciona el archivo en el selector de macOS; el archivo se cargará en el directorio remoto actual.
4. **Descargar archivos:**
   - Selecciona un archivo en la lista (los directorios no habilitan el botón de descarga individual).
   - Haz clic en el botón **Download** (􀁸) y escoge la ubicación de destino en tu Mac mediante el `NSSavePanel`.

### 3.3 Transferencias Rápidas: Atajos, Drag & Drop y Descarga Contextual

Spectre Pro ofrece tres métodos acelerados para mover archivos sin abrir el modal SFTP:

1. **Atajo `⌘⇧U` (`Cmd+Shift+U`):**
   - Pulsa `⌘⇧U` dentro de la sesión remota. Se abre de inmediato el panel del sistema para elegir un archivo local y subirlo a la carpeta de trabajo remota.
2. **Arrastrar y Soltar (Drag & Drop):**
   - Arrastra uno o más archivos desde Finder (o desde el escritorio) y suéltalos directamente sobre la ventana de la terminal.
   - La terminal detecta el tipo MIME y lanza el worker de transferencia en background con una barra de progreso flotante.
3. **Descarga Contextual desde Selección de Texto:**
   - Si un comando lista un archivo (por ejemplo, ejecutas `ls -la` y ves `database_backup_20260914.sql.gz` o `/var/log/syslog`), **selecciona el texto con el mouse**.
   - Haz **clic derecho**: aparecerá la opción:
     > **`Download 'database_backup_20260914.sql.gz' to ~/Downloads`**
   - Haz clic y el archivo se transferirá inmediatamente a tu carpeta local de Descargas sin interrumpir lo que estás escribiendo en la terminal.

### 3.4 Motor de Cola Persistente y Algoritmo de Reintento

El `SSHTransferManager` implementa una cola con estado persistente guardada en `transfers.json`:
- **Cálculo de Progreso Real:** El parser decodifica los mensajes de estado de SCP (`parseProgressPercentage`) para calcular porcentajes exactos, tasa de transferencia y tiempo estimado restante.
- **Escaping Robusto:** Todas las rutas con espacios, comillas o caracteres especiales se procesan mediante `shellEscaped()`, evitando fallos silenciosos por errores de sintaxis en el comando remoto.
- **Manejo de Fallos:** Si la conexión se interrumpe durante una transferencia, la tarea entra en estado de espera y se reanuda cuando el controlador de reconexión restablece el enlace.

---

## 4. Quick Commands & Automatización Dinámica de Terminal

Acceso: **`⌘⇧B` (`Cmd+Shift+B`)**, botón de barra lateral en la cabecera, o menú **View → Quick Commands**.

### 4.1 Modos de Inyección (`▶ Run` vs `✎ Insert`) y Split & Run

Cada tarjeta de comando en la barra lateral ofrece múltiples métodos de interacción:
- **Botón `▶ Run` (o tecla `Return`):** Envía la cadena de comando al PTY activo seguido de un retorno de carro (`\r`). Se ejecuta de inmediato.
- **Botón `✎ Insert` (o tecla `⌥ Return`):** Inserta el texto del comando en el prompt sin pulsar Enter. Te permite inspeccionar parámetros o concatenar pipes (`| grep ...`) manualmente.
- **Split & Run:** Al pasar el cursor sobre la tarjeta, aparece el ícono de división. Al hacer clic, Spectre Pro crea un split vertical a la derecha del panel actual y ejecuta el comando de inmediato en el nuevo split.

### 4.2 Interpolación Dinámica de Variables y Tokens de Contexto

Puedes parametrizar tus comandos utilizando dos sintaxis:

1. **Variables con Modal Interactivo (`<variable>` o `{variable}`):**
   - Ejemplo de comando guardado:
     ```bash
     docker logs -f --tail=<lineas> <contenedor>
     ```
   - Al ejecutarlo, Spectre Pro intercepta las variables y abre una ventana modal con campos de texto para `lineas` y `contenedor`. Al confirmar, sustituye los valores y envía el comando final.
2. **Tokens de Inyección Automática de Contexto:**
   - `{clipboard}`: Se reemplaza en tiempo real por el contenido actual del portapapeles de macOS.
     - Ejemplo: `curl -X POST -H "Authorization: Bearer {clipboard}" https://api.empresa.com/v1/deploy`
   - `{selection}`: Se reemplaza por el texto seleccionado actualmente en el búfer de la terminal activa.
     - Ejemplo: `kubectl describe pod {selection}`

### 4.3 Broadcast Mode: Concurrencia sobre Splits Activos

Inspirado en flujos de trabajo de terminales de misión crítica:
1. En la cabecera de la barra lateral de Quick Commands, haz clic en el ícono de **Broadcast** (antena/ondas).
2. Cuando el modo está activo (indicador encendido en color de acento), cualquier comando que ejecutes o insertes se replicará **simultáneamente en todas las divisiones (splits) de la ventana activa**.
3. Permite aplicar parches, recargar servicios o verificar versiones en múltiples servidores abiertos lado a lado con una sola pulsación.

### 4.4 Aislamiento de Foco y Máquina de Estados del Teclado

Spectre Pro resuelve el problema común de las barras laterales que secuestran teclas:
- **Zero-Conflict:** La interceptación de teclas (`↑`, `↓`, `Return`, `Esc`) ocurre **única y exclusivamente** cuando el foco del sistema (`firstResponder`) reside en la vista de Quick Commands.
- En cuanto pulsas `Return` o `Esc`, el foco se devuelve de inmediato a la terminal Metal, garantizando que atajos como `Ctrl+R`, `Ctrl+C` o flechas en `vim`/`zsh` no sufran retrasos ni interferencias.

---

## 5. Monitor de Procesos Darwin & Orquestación de Background Jobs

Spectre Pro monitoriza de forma continua el proceso que corre en la terminal mediante llamadas directas al kernel de macOS (Darwin XNU).

### 5.1 Telemetría de CPU en Microsegundos vía `proc_pidinfo`

El subsistema `TerminalProcessMonitor` no ejecuta comandos costosos como `ps` o `top`. Consulta directamente las estructuras del kernel:
```c
proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task_info, sizeof(task_info));
```
Calcula la derivada en microsegundos de tiempo de CPU de usuario y sistema (`pti_total_user + pti_total_system`) agregando todos los subprocesos del árbol de ejecución.

### 5.2 Estados Braille y Ventana de Histéresis

La actividad se visualiza en la barra de título o barra superior mediante glifos Unicode Braille nativos:
- **Activo:** Si el proceso consume CPU por encima del umbral o realiza I/O intenso, se activa el ecualizador animado:
  `[◈ cargo build ⣀⣄⣤⣦ active]`
- **Inactivo / Idle:** Cuando el comando entra en espera de entrada de usuario (`read`, prompt interactivo) o reposo, cambia a:
  `[◈ zsh ⣀⣀⣀⣀ idle]`
- **Ventana de Histéresis de 2.5 Segundos:** Para evitar parpadeos visuales durante compilaciones por ráfagas o comandos con pausas breves, el estado activo se retiene durante 2.5 segundos antes de declarar el proceso como inactivo. Cuando está en reposo, los timers de `TimelineView` se detienen por completo, reduciendo el consumo de CPU de la app a **0.0%**.

### 5.3 Ciclo de Vida y Terminación de Tareas en Segundo Plano

Si ejecutas procesos en background (`./server &` o `python3 worker.py &`):
1. Spectre Pro detecta la creación de subprocesos no bloqueantes y muestra una píldora indicadora en la barra: `[⠋ 2 bg]`.
2. Al hacer clic en la píldora, se despliega un popover interactivo con:
   - Nombre del proceso.
   - PID del sistema.
   - Tiempo de ejecución acumulado.
   - **Botón Kill:** Envía una señal `SIGTERM` (y posteriormente `SIGKILL` si no responde) para detener el proceso sin tener que buscar manualmente el PID con `kill -9`.
3. Al finalizar un proceso, se muestra brevemente una notificación no intrusiva: `[✓ worker.py finished]`.

---

## 6. Resiliencia de Conexión: Reconexión Reactiva y Mitigación MITM

### 6.1 Detección de Enlace con `NWPathMonitor`

Las herramientas tradicionales esperan a que el socket de OpenSSH agote su timeout de keepalive (a menudo varios minutos) tras perder conexión.
- Spectre Pro integra el framework nativo `Network.framework` (`NWPathMonitor`).
- En cuanto el Mac apaga el adaptador Wi-Fi, entra en suspensión o desconecta una VPN, el monitor marca inmediatamente el estado `.networkUnavailable`.
- Esto previene que la terminal quede congelada y pausa temporalmente los reintentos para no degradar la batería.

### 6.2 Máquina de Estados de Reconexión y Backoff

Al recuperar la conectividad, el `SSHReconnectController` ejecuta una secuencia de reconexión controlada:

```
[CONEXIÓN PERDIDA] ──> [NWPathMonitor: ¿Hay Red?]
                              │
             ┌────────────────┴────────────────┐
             ▼ NO                              ▼ SÍ
   [Estado: .waitingForNetwork]       [Backoff Exponencial: 1s, 2s, 4s, 8s...]
             │                                 │
             └────────► [Red Detectada] ───────┘
                               │
                               ▼
                    [Reintento de Conexión SSH]
                               │
             ┌─────────────────┴─────────────────┐
             ▼ Éxito                             ▼ Fallo
   [Restaura Sesión / PTY]              [Incrementa Intento / UI Toast]
```

- **Controles en Pantalla:** Durante la reconexión, un toast no bloqueante muestra el número de intento y ofrece botones para **Pausar**, **Reanudar** o **Cancelar**.
- **Preservación de Estado:** El historial de la terminal, las variables exportadas del runtime y los buffers de salida no se pierden.

### 6.3 Verificación Estricta de Claves de Host y Alerta Toast

Spectre Pro no utiliza opciones inseguras como `StrictHostKeyChecking=no`.
- Si el fingerprint del servidor remoto cambia (potencial ataque Man-in-the-Middle o servidor reinstalado), la conexión se suspende de inmediato.
- Se dispara un modal de advertencia crítica (`HostKeyAlertToast`) que muestra:
  - El hostname y puerto.
  - La clave de host anterior almacenada en `known_hosts`.
  - La nueva clave presentada por el servidor.
  - Opciones explícitas: **Rechazar y Cerrar** o **Actualizar Host Key y Continuar** (registrando la decisión en auditoría).

---

## 7. Session Logger: Auditoría Forense y Sanitización de Secretos en Vivo

Ubicación: Icono de grabación en la barra superior o configuración de sesión en el Session Manager.

### 7.1 Captura Real de Pantalla vs Snapshots Sintéticos

El `SessionLogger` de Spectre Pro no es un simple volcado de comandos escritos:
- Se conecta directamente al pipeline de salida del terminal (`ingestScreenText`).
- Captura la salida real devuelta por los programas, salidas de error (`stderr`), banners de inicio de sesión y respuestas interactivas.
- Opcionalmente elimina secuencias de escape ANSI (colores y posicionamiento de cursor) para generar archivos de texto limpios listos para adjuntar en tickets de Jira, informes SOC2 o pull requests.

### 7.2 Motor de Redacción Heurística y Reglas de Expresiones Regulares

Cuando la opción `sanitizeSensitiveData` está activa (activada por defecto), el flujo de texto pasa por un motor de sanitización de un solo paso antes de tocar el disco:

| Tipo de Dato Sensible | Patrón Detectado | Reemplazo en Log |
| --- | --- | --- |
| **Contraseñas / Passwords** | `(?i)(password\|passphrase\|passwd\|secret)\s*[:=]\s*\S+` | `$1: [REDACTED]` |
| **Bearer / Auth Tokens** | `(?i)(bearer\|token\|authorization\|auth)\s*[:=]\s*\S+` | `$1: [REDACTED]` |
| **AWS Access Keys** | `(?:AKIA\|ASIA)[A-Z0-9]{16}` | `[REDACTED]` |
| **SSH Private Keys** | `-----BEGIN[^-]*PRIVATE KEY-----[\s\S]*?-----END...` | `[PRIVATE KEY REDACTED]` |
| **Variables en Shell** | `(?i)export\s+\w*(KEY\|TOKEN\|SECRET\|PASS)\w*\s*=\s*\S+` | `export CLAVE=[REDACTED]` |
| **JSON Web Tokens (JWT)**| `eyJ[A-Za-z0-9_-]{10,}\.eyJ...` | `[JWT REDACTED]` |
| **Personal Access Tokens**| `(?:ghp_\|gho_\|ghs_\|glpat-)[A-Za-z0-9_-]{20,}` | `[TOKEN REDACTED]` |

El log final queda almacenado en `~/Library/Application Support/SpectrePro/logs/` con formato ISO8601 y hash de verificación.

---

## 8. Automation Hub: Orquestación Declarativa Multi-Host

Acceso: Pestaña **Automation** dentro del Session Manager (`⌘⇧S`).

### 8.1 Modelo Declarativo de Planes y Políticas de Aislamiento

Un plan de automatización (`AutomationPlan`) se define mediante una secuencia de pasos (`AutomationStep`) ejecutados bajo una directiva de seguridad (`AutomationPolicy`):
- **Permisos granulares:** Red (`allowNetwork`), ejecución local de subprocesos (`allowLocalShell`), acceso a archivos (`allowFileSystem`), acceso a Keychain (`allowKeychain`) y confirmación de producción (`allowProduction`).
- **Límites de Seguridad:** Número máximo de hosts en paralelo (`maxTargets = 50`) y tiempo límite global (`timeoutLimitSeconds = 300`).

### 8.2 Reglas Expect/Send Vinculadas a Keychain

Para tareas que requieren interacción con prompts (ej. cambiar contraseña, ingresar código OTP, aceptar avisos de sudo):
1. Cada paso `ExpectSendRule` define un patrón de búsqueda (`expect`) y una respuesta (`send`).
2. **Uso de Keychain en lugar de texto plano:** En vez de escribir la contraseña en la regla, se enlaza un `CredentialReference`.
3. Al encontrar el texto esperado en la pantalla (ej. `[sudo] password for admin:`), el motor solicita la resolución de la credencial en tiempo de ejecución al Keychain local y envía la cadena al PTY sin exponerla en logs ni en la interfaz visual.

### 8.3 Fase de Previsualización Mandatoria y Guardarraíles de Producción

Para evitar accidentes catastróficos en flotas de servidores:
1. Al pulsar **Execute Plan**, Spectre Pro compila un objeto `AutomationPreviewInfo`.
2. Se presenta una ventana modal obligatoria que muestra:
   - La lista exacta de servidores destino que recibirán la ejecución.
   - La secuencia ordenada de comandos a ejecutar.
   - Advertencia si alguno de los hosts tiene la etiqueta `production`.
3. Si hay destinos de producción, el botón de ejecución requiere activación explícita mediante un interruptor de doble confirmación (**Confirm Production Execution**).

### 8.4 Análisis del Historial de Ejecución y Auditoría Forense

Al completarse el plan:
- Cada host recibe un resultado independiente: `.success`, `.failed(error)` o `.skipped`.
- Si un servidor falla, la política determina si se detiene la secuencia global o si se continúa con los servidores restantes (`continueOnError`).
- El informe completo se guarda en `automation_history.json`, incluyendo marcas de tiempo, duración exacta por paso en milisegundos y código de retorno devuelto por cada servidor.

---

## 9. Workspace Hub: Diagnóstico de Incidentes y Comparador Multi-Host

Acceso: Pestaña **Workspaces** dentro del Session Manager (`⌘⇧S`).

### 9.1 Persistencia Atómica del Árbol de Splits y Pestañas

Spectre Pro modela tu entorno como un árbol jerárquico (`WorkspaceSplitNode`) que contiene tabs y divisiones verticales/horizontales:
- El guardado se realiza de manera atómica: escribe en un archivo temporal (`.tmp`), fuerza la sincronización con disco (`fsync`), y realiza un renombrado atómico (`rename`) con permisos restrictivos `0o600`.
- Si el Mac se apaga inesperadamente, el archivo de workspace anterior nunca queda en estado corrupto o incompleto.
- Al reiniciar la aplicación, se restaura la topología de ventanas, los servidores conectados en cada split y los directorios de trabajo.

### 9.2 Timeline Unificado de Incidentes

Durante una guardia o atención de incidentes (SRE On-Call):
- Cada evento operativo se registra cronológicamente en el workspace activo:
  - Eventos de conexión y desconexión.
  - Comandos relevantes ejecutados.
  - Mensajes de error detectados en terminales.
  - Transferencias de archivos realizadas.
  - Alertas de seguridad o reconexiones de red.
- La interfaz permite filtrar por tipo de evento (`Connection`, `Command`, `Error`, `Transfer`, `SecurityAlert`).

### 9.3 Multi-Host Output Clustering y Detección de Anomalías (Outliers)

Cuando ejecutas un comando de diagnóstico a través de múltiples nodos (ej. `systemctl status patroni` o `openssl version`):
1. Dirígete a la pestaña **Multi-Host Diff**.
2. El comparador (`MultiHostComparator`) toma las salidas de todos los hosts y las agrupa automáticamente en grupos idénticos mediante funciones de hash de texto normalizado.
3. **Detección Automática de Outliers:**
   - Si 9 servidores devuelven el mismo output y 1 servidor devuelve un error o una versión distinta, Spectre Pro marca inmediatamente ese servidor con la insignia **`[ANOMALÍA / OUTLIER]`** en color naranja/rojo.
   - Permite detectar en un segundo qué nodo de un clúster está desincronizado o fallando sin tener que leer manualmente los logs de 10 terminales abiertas.

### 9.4 Generación y Exportación del Incident Bundle Sanitizado

Para compartir el diagnóstico de un incidente con el equipo o adjuntarlo a un post-mortem:
1. Haz clic en el botón **`Export Bundle`** en la cabecera del Workspace Hub.
2. El exportador (`IncidentBundleExporter`) genera un paquete estructurado:
   - Metadatos del incidente (hora de inicio, fin, operadores involucrados).
   - El timeline completo de eventos.
   - Las notas y la lista de comandos ejecutados/pendientes.
   - Los reportes de comparación multi-host.
3. **Garantía de Privacidad:** El motor aplica sanitización estricta sobre todo el bundle antes de comprimirlo, garantizando que no se filtren contraseñas, variables de entorno privadas ni tokens en el reporte exportado.

---

## 10. Fleet Hub: Telemetría de Flota y Salud Operativa

Acceso: Pestaña **Fleet** dentro del Session Manager (`⌘⇧S`).

### 10.1 Pings Asíncronos Paralelos y Medición de Latencia

El `FleetManager` permite supervisar la disponibilidad de toda tu infraestructura de forma no intrusiva:
- Haz clic en el botón **`Ping Fleet`** (ícono de electrocardiograma 􀊄).
- Utiliza tareas concurrentes asíncronas de Swift (`TaskGroup`) para verificar la conectividad de decenas de servidores en paralelo sin bloquear la interfaz gráfica.
- Registra el tiempo de ida y vuelta (RTT) en milisegundos y clasifica el estado de cada nodo:
  - 🟢 **Online / Saludable:** Respuesta en tiempo y sin pérdidas de paquetes.
  - 🟡 **Degradado:** Latencia alta o fluctuaciones de conexión.
  - 🔴 **Inalcanzable / Caído:** Timeout en el sondeo de red.

### 10.2 Monitoreo de Túneles y Vencimiento de Certificados

- **Supervisión de Túneles:** Lista qué puertos locales están enlazados activamente a sockets remotos.
- **Detección Preventiva de Certificados:** Inspecciona las fechas de expiración de certificados SSL/TLS o claves SSH asignadas a los hosts y muestra una alerta visual cuando un certificado se encuentra a menos de 14 días de expirar.

---

## 11. Consola Serial: Perfiles de Fabricante y Control de Flujo

Acceso: Pestaña **New Session → Serial** en el Session Manager.

### 11.1 Detección de Controladores USB-Serie en macOS

Spectre Pro escanea los dispositivos IOKit de macOS (`IOServiceGetMatchingServices`) y detecta automáticamente adaptadores USB a Serie comunes:
- Chips FTDI (`/dev/cu.usbserial-*`)
- Silicon Labs CP210x (`/dev/cu.SLAB_USBtoUART*`)
- Prolific PL2303 (`/dev/cu.usbserial*`)
- Qinheng CH340/CH341 (`/dev/cu.wchusbserial*`)

### 11.2 Perfiles por Fabricante (`SerialHardwareManufacturer`)

Cada tipo de hardware de telecomunicaciones tiene particularidades en su consola de gestión. Spectre Pro incluye perfiles de configuración directa:

| Fabricante | Baud Rate | Data / Parity / Stop | Flow Control | Comportamiento Especial |
| --- | --- | --- | --- | --- |
| **Cisco Systems** | 9600 bps | 8 / None / 1 | None | Retardo entre líneas de 20ms para prompts de configuración de IOS/IOS-XE. |
| **Juniper Networks** | 9600 bps | 8 / None / 1 | Hardware (RTS/CTS) | Pacing optimizado para commit de configuraciones en JunOS. |
| **Arista Networks** | 9600 bps | 8 / None / 1 | None | Detección de prompts Aboot y EOS. |
| **MikroTik RouterOS**| 115200 bps | 8 / None / 1 | None | Baud rate acelerado para consolas modernas de RouterBOARD. |
| **Genérico / Custom** | 300 a 230400 | Configurable | None / XON/XOFF / RTS/CTS | Permite parametrización manual completa para IoT y sistemas embebidos. |

### 11.3 Rate-Limiting Anti-Desbordamiento de FIFO

Al pegar scripts o listas de control de acceso (ACLs) de cientos de líneas en una consola serie antigua, el chip UART del router suele saturarse, perdiendo caracteres o truncando comandos.
- Spectre Pro aplica un mecanismo de **line-pacing inteligente**: introduce una pausa calibrada tras cada retorno de carro (`\r`), esperando el eco del prompt del switch antes de despachar el siguiente bloque de texto.

---

## 12. Casos de Uso Reales de Extremo a Extremo (Runbooks)

### Escenario 1: Triaje de Incidente en un Clúster Web en Producción

1. **Apertura de Sesión:** Abre el Session Manager (`⌘⇧S`) y conecta la sesión guardada para el grupo `webservers`.
2. **División de Pantalla:** Pulsa `⌘D` para crear un split lateral y conecta el segundo nodo.
3. **Diagnóstico Rápido:** Abre la barra de Quick Commands (`⌘⇧B`), activa el **Modo Broadcast** y ejecuta:
   ```bash
   tail -n 20 /var/log/nginx/error.log
   ```
4. **Comparación Multi-Host:** En el Session Manager, abre **Workspaces → Multi-Host Diff**, ingresa el comando de verificación y observa cómo Spectre Pro aísla el servidor anómalo.
5. **Descarga de Evidencia:** Selecciona la ruta del archivo `/var/log/nginx/error.log` en pantalla, haz clic derecho y selecciona **Download to ~/Downloads**.
6. **Exportación de Reporte:** Haz clic en **Export Bundle** en el Workspace Hub para generar el zip sanitizado y compartirlo en el canal del incidente.

### Escenario 2: Despliegue de Emergencia con Múltiples Saltos y Expect/Send

1. Configura la sesión del servidor de base de datos con **Jump Host** apuntando al Bastion corporativo.
2. Crea un plan en el **Automation Hub** usando la plantilla **Deployment**:
   - Paso 1: `git pull origin release-1.0.24`
   - Paso 2: `sudo systemctl restart backend-worker` (vinculado a la contraseña de sudo guardada en Keychain).
3. Pulsa **Execute Plan**: revisa la ventana modal de **Preview**.
4. Activa la confirmación de producción y confirma la ejecución.
5. Observa el progreso paso a paso; la clave de sudo se envía automáticamente sin mostrarse en pantalla y el log queda sanitizado.

---

## 13. Referencia Rápida de Atajos de Teclado y Comandos

### Ventanas, Pestañas y Splits
- **`⌘T`**: Nueva pestaña de terminal.
- **`⌘D`**: Dividir pestaña verticalmente (Split Right).
- **`⌘⇧D`**: Dividir pestaña horizontalmente (Split Down).
- **`⌘W`**: Cerrar pestaña o split activo.
- **`⌘[` / `⌘]`**: Navegar entre splits de la ventana.
- **`⌘K`**: Limpiar la pantalla y el búfer de scroll.

### Herramientas Integradas de Spectre Pro
- **`⌘⇧S`**: Abrir / Cerrar el **Session Manager** (Sesiones, Workspaces, Automatización, Flota).
- **`⌘⇧B`**: Abrir / Cerrar la barra lateral de **Quick Commands**.
- **`⌘⇧U`**: Abrir diálogo de **subida rápida de archivo** a la sesión SSH activa.
- **Clic derecho en terminal**: Menú contextual con **Open SFTP Browser**, Upload y Download de selección.
- **Arrastrar archivo al terminal**: Transferencia inmediata vía SCP/SFTP.

### Teclado en Barra de Quick Commands
- **`↑` / `↓`**: Moverse por la lista de comandos.
- **`Return`**: Ejecutar el comando inmediatamente en la terminal activa.
- **`⌥ Return`**: Insertar el texto del comando en el prompt sin ejecutar.
- **`Esc`**: Salir del cuadro de búsqueda y regresar el foco a la terminal.

---

*Manual de Operaciones y Referencia Técnica — Spectre Pro v1.0.24 — Skyones.*
