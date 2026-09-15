# Guía de Funciones Integradas de Spectre Pro

Esta guía detalla el funcionamiento, atajos de teclado y casos de uso prácticos de cada una de las herramientas y subsistemas integrados en **Spectre Pro**.

---

## Tabla de Contenidos

1. [Session Manager (Administrador de Sesiones)](#1-session-manager-administrador-de-sesiones)
2. [Navegador SFTP y Transferencias de Archivos](#2-navegador-sftp-y-transferencias-de-archivos)
3. [Quick Commands & Barra Lateral Inteligente](#3-quick-commands--barra-lateral-inteligente)
4. [Monitor de Procesos y Trabajos en Segundo Plano](#4-monitor-de-procesos-y-trabajos-en-segundo-plano)
5. [Reconexión Automática y Detección de Red](#5-reconexión-automática-y-detección-de-red)
6. [Session Logger (Grabación y Sanitización en Vivo)](#6-session-logger-grabación-y-sanitización-en-vivo)
7. [Automation Hub (Automatización Profesional & Expect/Send)](#7-automation-hub-automatización-profesional--expectsend)
8. [Workspace Hub & Diagnóstico de Incidentes](#8-workspace-hub--diagnóstico-de-incidentes)
9. [Fleet Hub (Monitoreo de Salud de Servidores)](#9-fleet-hub-monitoreo-de-salud-de-servidores)
10. [Consola Serial & Perfiles de Fabricante](#10-consola-serial--perfiles-de-fabricante)
11. [Tabla Rápida de Atajos de Teclado](#11-tabla-rápida-de-atajos-de-teclado)

---

## 1. Session Manager (Administrador de Sesiones)

El **Session Manager** es el núcleo de gestión de conexiones de Spectre Pro. Permite crear, organizar, aislar y conectar sesiones remotas con estándares de seguridad bancaria/empresarial.

- **Cómo abrirlo:** Presiona `⌘⇧S` (`Cmd+Shift+S`) o selecciónalo en el menú principal.

### Capacidades clave:

- **Protocolos Soportados:** SSH, Telnet y Consola Serial.
- **Aislamiento por Pestaña (`RemoteSessionRuntime`):** Cada conexión que abres tiene su propio espacio de memoria, cola de transferencias, motor de automatización y logger aislados. Ninguna pestaña comparte buffers o estado con otra.
- **Seguridad en Keychain de macOS:** Las contraseñas, passphrases de llaves privadas y tokens nunca se guardan en texto plano en archivos JSON. Se almacenan cifrados en el Keychain de macOS mediante referencias `CredentialReference` únicas.
- **Jump Host / Bastion:** Configura servidores intermedios de salto sin necesidad de editar manualmente directivas de OpenSSH.
- **Túneles SSH (Port Forwarding):**
  - **Locales (`-L`):** Redirige un puerto de tu Mac hacia un servicio en la red remota (ej. `localhost:5432` hacia la base de datos remota).
  - **Remotos (`-R`):** Expone un puerto de tu máquina local hacia el servidor remoto.
- **Importación y Exportación de Inventarios:**
  - Importa hosts desde `~/.ssh/config`.
  - Importa inventarios de **Ansible** (formatos INI y YAML).
  - Exporta/Importa colecciones completas en formato JSON/YAML versionado sin exponer credenciales.

---

## 2. Navegador SFTP y Transferencias de Archivos

Spectre Pro incluye capacidades completas de transferencia de archivos que aprovechan la conexión SSH activa mediante multiplexación (`ControlMaster`), eliminando la necesidad de volver a autenticarse.

### A. Abrir el Navegador Gráfico SFTP
1. En una pestaña conectada por SSH, haz **clic derecho** sobre cualquier área del terminal.
2. Selecciona **`Open SFTP Browser...`** (ícono de carpeta 📁).
3. Se desplegará el panel interactivo:
   - **Navegar:** Escribe una ruta remota (ej. `/var/log` o `/home/usuario`) y presiona `Enter` o haz doble clic sobre cualquier directorio.
   - **Subir archivo:** Haz clic en el botón de subida (􀁶) y selecciona el archivo en el selector nativo de macOS.
   - **Descargar archivo:** Selecciona el archivo remoto en la lista y haz clic en el botón de descarga (􀁸).
   - **Refrescar:** Botón 􀅈 para actualizar el listado del servidor.

### B. Subida Rápida de Archivos
- **Atajo `⌘⇧U`:** Presiona `Cmd+Shift+U` en la terminal para abrir el selector de archivos y subirlo directamente al directorio de trabajo actual.
- **Drag & Drop (Arrastrar y Soltar):** Arrastra uno o varios archivos desde Finder y suéltalos directamente sobre la ventana de la terminal. Spectre Pro iniciará la transferencia SCP/SFTP automáticamente mostrando el progreso.

### C. Descarga Rápida desde la Pantalla
- Si ves el nombre o ruta de un archivo en la terminal (por ejemplo `nginx.conf` o `/var/log/syslog`), **selecciónalo con el cursor**, haz **clic derecho** y elige:
  > **Download '[archivo]' to ~/Downloads**
- El archivo se descargará automáticamente a tu carpeta de Descargas.

### D. Cola Persistente de Transferencias
- Las transferencias se gestionan en una cola con reintentos automáticos y prioridad.
- Las transferencias no bloquean el uso de la terminal interactiva.

---

## 3. Quick Commands & Barra Lateral Inteligente

La barra lateral de comandos rápidos te permite ejecutar instrucciones frecuentes con un clic o mediante atajos de teclado sin salir de tu flujo de trabajo.

- **Cómo abrirla:** Presiona `⌘⇧B` (`Cmd+Shift+B`), presiona el botón de la barra lateral en la barra superior, o selecciona **View → Quick Commands**.

### Capacidades:

- **Modo Ejecución (▶):** Envía el comando al shell y ejecuta un salto de línea (`\r`) inmediatamente.
- **Modo Inserción (✎):** Escribe el texto en el prompt sin pulsar Enter, permitiéndote revisarlo o editarlo antes de ejecutarlo.
- **Split & Run:** Pasa el cursor sobre un comando y pulsa el ícono de split para abrir una división a la derecha y ejecutar el comando automáticamente en ella.
- **Placeholders Dinámicos:**
  - Si un comando contiene variables como `<host>`, `<puerto>` o `{branch}`, al hacer clic se abrirá un modal interactivo para ingresar los valores antes del envío.
  - Soporta tokens de auto-inyección: `{clipboard}` (pega el portapapeles) y `{selection}` (inyecta el texto seleccionado en el terminal).
- **Broadcast Mode (Modo Difusión):**
  - Haz clic en el ícono de broadcast (antena) en la cabecera de la barra lateral.
  - Al estar activo, cualquier comando enviado se transmitirá **a todos los splits abiertos simultáneamente**.
- **Navegación por Teclado:**
  - `↑` / `↓`: Navegar entre comandos.
  - `Return`: Ejecuta el comando seleccionado y regresa el foco a la terminal.
  - `⌥ Return` (`Option + Enter`): Inserta el comando sin ejecutarlo.
  - `Escape`: Cierra o desfoca la barra de búsqueda.

---

## 4. Monitor de Procesos y Trabajos en Segundo Plano

Spectre Pro incluye un monitor de procesos en tiempo real con bajísimo consumo de recursos que analiza la actividad del shell a nivel de microsegundos de CPU.

### A. Indicador de Actividad Braille
- En la barra superior verás el nombre del proceso activo y su estado con glifos Braille dinámicos:
  - **Activo:** `[◈ build ⣀⣄⣤⣦ active]` — Indica compilación, streaming de red o trabajo intensivo de CPU.
  - **Inactivo / Espera:** `[◈ zsh ⣀⣀⣀⣀ idle]` — Se suspende la animación y el consumo de CPU baja a 0.0%.

### B. Gestor de Tareas en Segundo Plano (`[⠋ N bg]`)
- Cuando ejecutas comandos en segundo plano (como `sleep 60 &`, servidores locales, etc.), Spectre Pro los detecta automáticamente y muestra una píldora naranja en la barra superior.
- **Hacer clic en la píldora:** Abre un popover interactivo que lista cada tarea con su PID y nombre.
- **Botón Kill:** Puedes terminar cualquier proceso con un clic enviando una señal `SIGTERM`.
- Al finalizar un proceso de fondo, recibirás una notificación visual (ej. `✓ build finished`).

---

## 5. Reconexión Automática y Detección de Red

Diseñado para soportar cierres de tapa de laptops, cambios de Wi-Fi y caídas temporales de enlaces VPN.

- **Detección Nativa (`NWPathMonitor`):** Detecta inmediatamente cuando el Mac pierde conectividad de red y pausa los reintentos para no saturar el sistema ni bloquear la interfaz.
- **Backoff Exponencial:** Al restablecerse la red, realiza reintentos progresivos sin perder el buffer ni el historial de tu sesión.
- **Control Manual:** Mientras intenta reconectar, dispones de botones para **Pausar**, **Reanudar** o **Cancelar** la reconexión.
- **Protección de Host Key:** Si la clave del servidor remoto cambia imprevistamente, Spectre Pro bloquea la conexión y muestra una alerta visual detallada (`HostKeyAlertToast`) evitando ataques de intermediario (MITM).

---

## 6. Session Logger (Grabación y Sanitización en Vivo)

Permite auditar y archivar todo lo que sucede en la terminal garantizando el cumplimiento de normas de seguridad de la información.

- **Conexión Real de Pantalla:** Graba los cambios y salidas en tiempo real (`ingestScreenText`).
- **Sanitización Automática de Secretos:**
  El motor de registro analiza el texto en vivo y reemplaza automáticamente datos confidenciales por etiquetas de redacción:
  - Contraseñas y passphrases (`password: *****` → `[REDACTED]`)
  - Tokens de autenticación y Bearer tokens (`Bearer eyJ...` → `[REDACTED]`)
  - Tokens personales de GitHub y GitLab (`ghp_...`, `glpat-...` → `[TOKEN REDACTED]`)
  - Claves de acceso de Amazon Web Services (`AKIA...`, `ASIA...` → `[REDACTED]`)
  - Claves privadas SSH (`-----BEGIN OPENSSH PRIVATE KEY-----` → `[PRIVATE KEY REDACTED]`)
  - Comandos de exportación (`export API_KEY=...` → valor redactado)
- **Indicador Visual:** Un punto rojo parpadeante en la barra superior notifica cuando una sesión está siendo grabada.

---

## 7. Automation Hub (Automatización Profesional & Expect/Send)

Ubicado en la pestaña **Automation** del Administrador de Sesiones (`⌘⇧S`). Permite orquestar tareas repetitivas en uno o múltiples servidores.

### Plantillas Integradas:
1. **Login & Escalation:** Espera prompts de acceso y escala privilegios con `sudo` o `su`.
2. **Health Check:** Verifica uso de disco (`df -h`), memoria (`free -m`), carga de CPU y estado de servicios.
3. **Deployment:** Ejecuta pulls de git, recarga demonios del sistema y valida respuestas HTTP.
4. **Backup:** Empaqueta directorios críticos y valida checksums.
5. **Credential Rotation:** Cambia llaves o contraseñas de forma coordinada.

### Medidas de Seguridad:
- **Keychain en Expect/Send:** Los pasos que envían contraseñas o passphrases se enlazan al Keychain de macOS; la contraseña no se escribe en la regla de automatización.
- **Preview Obligatorio:** Antes de ejecutar un plan sobre múltiples servidores, Spectre Pro muestra un desglose de los comandos, los hosts involucrados y solicita confirmación explícita.
- **Protección de Producción:** Requiere confirmación biométrica/manual adicional para destinos marcados como entorno de producción.
- **Historial Completo:** Las ejecuciones quedan guardadas en `automation_history.json` con fecha, duración, usuario y resultado independiente por cada host.

---

## 8. Workspace Hub & Diagnóstico de Incidentes

Ubicado en la pestaña **Workspaces** del Administrador de Sesiones (`⌘⇧S`). Diseñado para responder a incidentes y mantener contextos de trabajo complejos.

- **Persistencia Atómica:** Guarda la distribución exacta de pestañas, splits y sesiones activas. Si cierras la aplicación o reinicias tu Mac, tu espacio de trabajo se restaura intacto.
- **Timeline de Incidentes:** Visualiza en una línea de tiempo unificada todos los eventos ocurridos: conexiones, comandos ejecutados, errores devueltos, transferencias y reconexiones.
- **Bloc de Incidentes:** Permite anotar hallazgos, hipótesis y dejar una lista de comandos pendientes de ejecutar durante el mantenimiento.
- **Multi-Host Comparator (Comparador de Salidas):**
  - Ejecuta un comando de diagnóstico en varios servidores (ej. `uptime` o `rpm -qa`).
  - Spectre Pro agrupa automáticamente las salidas idénticas en clusters.
  - **Detección de Anomalías (Outliers):** Resalta en color de alerta aquel servidor cuya salida discrepa de la mayoría (ideal para encontrar nodos desactualizados o fallidos en un clúster).
- **Exportación de Incident Bundle:** Genera un archivo `.zip` con el timeline, notas y salidas de comandos con toda la información sensible sanitizada para compartir con tu equipo.

---

## 9. Fleet Hub (Monitoreo de Salud de Servidores)

Ubicado en la pestaña **Fleet** del Administrador de Sesiones (`⌘⇧S`).

- **Reachability & Latencia:** Envía pings de estado y mide la latencia en milisegundos hacia cada servidor de tu inventario.
- **Supervisión de Túneles:** Monitorea qué puertos locales y remotos están activos.
- **Alertas de Certificados:** Advierte con anticipación cuando un certificado SSH o SSL asociado a un host está próximo a expirar.

---

## 10. Consola Serial & Perfiles de Fabricante

Para ingenieros de red, infraestructura y hardware:

- **Detección de Puertos:** Detecta automáticamente adaptadores USB-a-Serial (FTDI, Prolific, CH340) conectados a tu Mac.
- **Perfiles de Fabricante Integrados (`SerialHardwareManufacturer`):**
  - **Cisco Systems:** 9600 baud, 8N1, control de flujo adaptativo.
  - **Juniper Networks:** 9600 baud, pausas optimizadas para JunOS.
  - **Arista Networks:** 9600 baud, soporte de secuencias de escape EOS.
  - **MikroTik RouterOS:** 115200 baud, rate-limiting ajustado para evitar pérdidas de caracteres.
  - **Genérico:** Totalmente personalizable en velocidad, bits de datos, paridad y bits de parada.
- **Rate-Limiting de Envío:** Previene que pegar scripts largos de configuración bloquee o desborde el búfer de entrada del equipo de telecomunicaciones.

---

## 11. Tabla Rápida de Atajos de Teclado

| Atajo | Función |
| --- | --- |
| **`⌘⇧S`** (`Cmd+Shift+S`) | Abrir el **Session Manager** (Sesiones, Workspaces, Automatización, Flota) |
| **`⌘⇧B`** (`Cmd+Shift+B`) | Abrir/Cerrar la barra lateral de **Quick Commands** |
| **`⌘⇧U`** (`Cmd+Shift+U`) | **Subir archivo** a la sesión SSH activa |
| **Clic derecho en terminal** | Menú contextual con **Open SFTP Browser**, Upload y Download |
| **Drag & Drop a terminal** | Subida automática de archivos mediante **SCP/SFTP** |
| **`Return`** (en Quick Commands) | Ejecutar el comando seleccionado |
| **`⌥ Return`** (en Quick Commands) | Insertar el comando en el prompt sin ejecutar |
| **`⌘D` / `⌘⇧D`** | Dividir terminal (Split Right / Split Down) |
| **`⌘W`** | Cerrar la pestaña o split activo |
| **`⌘K`** | Limpiar el buffer de la pantalla |

---

*Documentación oficial de Spectre Pro. Desarrollado por Skyones.*
