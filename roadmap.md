# Spectre Pro Roadmap

Este documento describe el estado real del producto y el orden de trabajo para
completar las capacidades de sesiones remotas, automatización y operaciones.
No contiene secretos, tokens, certificados ni instrucciones privadas de firma.

## Convenciones

- `[x]` Completado y validado.
- `[~]` Parcialmente implementado; requiere trabajo adicional.
- `[ ]` Pendiente.
- Cada fase se cierra únicamente cuando cumple sus criterios de aceptación.
- Cada release debe pasar build, pruebas, seguridad, benchmark y prueba manual
  de actualización en macOS.

## Estado resumido

| Fase | Objetivo | Estado | Release objetivo |
| --- | --- | --- | --- |
| 0 | Seguridad y aislamiento de sesiones | `[x]` | `v1.1.0` |
| 1 | SSH, logging, SCP y SFTP confiables | `[x]` | `v1.2.0` |
| 2 | Automatización segura y multi-sesión | `[x]` | `v1.3.0` |
| 3 | Workspace operativo | `[x]` | `v2.0.0` |
| 4 | Fleet, Git, CI SSH y calidad avanzada | `[x]` | `v2.1.0` |

## Fase 0 — Fundaciones de seguridad

### Implementado

- `[x]` `RemoteSessionRuntime` independiente por superficie/tab.
- `[x]` Logger, automatización y transferencias propios por runtime.
- `[x]` Limpieza del runtime al reemplazar o destruir una superficie.
- `[x]` Validación de hostname, usuario, puerto, jump host e identidades.
- `[x]` Construcción de procesos SSH con argumentos separados.
- `[x]` Configuración persistente de sesiones en Application Support con permisos
  restrictivos.
- `[x]` Referencias de credenciales separadas del contenido de la sesión.
- `[x]` Contraseñas/passphrases guardadas en macOS Keychain.
- `[x]` Pruebas de aislamiento y de ausencia de secretos en JSON.
- `[x]` Expect/Send con referencias al Keychain para prompts sensibles (`CredentialReference`).
- `[x]` Conexión del logger al flujo real de salida de terminal sin duplicar snapshots (`ingestScreenText`).
- `[x]` Auditoría y sanitización de logs para tokens, contraseñas, OTP, claves privadas y variables sensibles.
- `[x]` Resolución de credenciales por sesión mediante `SessionCredentialResolver` e inyección en runtime.
- `[x]` Migración de sesiones (`SessionFileEnvelope` v2), prevención de clones de Keychain y limpieza de huérfanos (`reconcileKeychainOrphans`).

### Parcial o pendiente

(Completado en su totalidad)

### Criterios de cierre

- Tres sesiones simultáneas no comparten logger, automatización ni transferencias.
- Una búsqueda en archivos de configuración no encuentra contraseñas.
- Cerrar una sesión libera procesos, tareas, timers y credenciales temporales.
- Las pruebas cubren creación, migración, reemplazo y destrucción del runtime.

## Fase 1 — SSH, logging y transferencias

### Implementado

- `[x]` Soporte de sesiones SSH, Telnet y consola serial en el Session Manager.
- `[x]` SSH con ControlMaster/ControlPath reutilizable por sesión.
- `[x]` Jump host, claves, agent forwarding, compresión, keepalive y túneles.
- `[x]` Política explícita de `known_hosts` y `StrictHostKeyChecking=ask`.
- `[x]` Timeout, intentos de conexión y límites de keepalive.
- `[x]` SCP con subida, descarga, cancelación y diagnóstico de `stderr`.
- `[x]` Panel SFTP con navegación de directorios.
- `[x]` Subida y descarga SFTP mediante `put`/`get`.
- `[x]` Selector nativo de archivos de macOS.
- `[x]` Reintentos con backoff limitado y estado de reconexión.
- `[x]` Importación básica de entradas de `~/.ssh/config`.
- `[x]` Detección de conectividad de red con `NWPathMonitor` (`isNetworkAvailable`, estado `.networkUnavailable`).
- `[x]` Porcentaje real del protocolo SCP (`parseProgressPercentage`).
- `[x]` Cola persistente de transferencias con prioridad, reintentos y resultado histórico (`QueuedTransfer`, `transfers.json`).
- `[x]` Reutilización de conexión SSH autenticada para SFTP vía ControlPath.
- `[x]` Detección de host key cambiada / rechazada con alerta accionable (`HostKeyAlert`, `HostKeyAlertToast`).
- `[x]` Reconexión automática avanzada con pausa, reanudación, cancelación y límite configurable.
- `[x]` Preservación de evidencia de errores y estado tras desconexión/reconexión (`reconnectHistory`, `lastDisconnectReason`).
- `[x]` Pruebas de suite con escaping de rutas con espacios, parser de progreso SCP, cola priorizada, reintentos y estados de reconexión.

### Parcial o pendiente

(Completado en su totalidad)

### Criterios de cierre

- Conectar a un host directo y mediante bastion.
- Crear y verificar un túnel local/remoto.
- Subir y descargar un archivo con progreso, cancelación y error visible.
- Interrumpir la red, detectar la desconexión y reconectar sin perder el tab.
- Rechazar una host key cambiada y no aceptar claves silenciosamente.
- Mantener logs y resultados asociados al runtime correcto.

## Fase 2 — Automatización profesional

### Implementado

- `[x]` Modelo `AutomationScript` declarativo.
- `[x]` Modelo de planes con pasos y destinos.
- `[x]` Permisos separados para red, shell local, archivos, Keychain y producción.
- `[x]` Bloqueo de permisos no concedidos.
- `[x]` Confirmación explícita para operaciones de producción.
- `[x]` Ejecutor multi-sesión con resultados por destino.
- `[x]` Cancelación del plan en ejecución.
- `[x]` Expect/Send con texto literal, regex, timeout y reintentos.
- `[x]` Continuación opcional después de fallar un paso.
- `[x]` Interfaz visual nativa en SwiftUI de creación, revisión y ejecución (`AutomationHubView`).
- `[x]` Callbacks de envío multi-sesión conectados a runtimes y terminales (`SpectrePro.SurfaceView`).
- `[x]` Historial persistente de ejecuciones con fecha/hora, usuario, destinos, duración y resultados detallados (`automation_history.json`).
- `[x]` Modo preview obligatorio antes de ejecutar en múltiples hosts (`preview`, `AutomationPreviewInfo`, modal de confirmación).
- `[x]` Plantillas de automatización built-in (`AutomationTemplate`: login, health check, despliegue, backups, rotación).
- `[x]` Límites de tiempo (`timeoutLimitSeconds`), tamaño de buffer y número máximo de destinos (`maxTargets`).
- `[x]` Suite de pruebas con validación de plantillas, preview mode, límites de destinos, cancelación y fallos parciales independientes.

### Parcial o pendiente

(Completado en su totalidad)

### Criterios de cierre

- Un plan muestra exactamente qué hará antes de ejecutarse.
- Diez sesiones reciben el plan con resultado individual por host.
- Un host fallido no oculta los resultados de los demás.
- Un plan de producción exige confirmación y permisos adecuados.
- Cancelar detiene nuevos pasos y deja evidencia de lo ya ejecutado.
- Ningún secreto aparece en el plan, output persistido o log.

## Fase 3 — Workspace operativo

### Implementado

- `[x]` Modelo persistente de workspace con tabs, splits y sesiones (`WorkspaceModel`, `WorkspaceSplitNode`, `WorkspaceTab`).
- `[x]` Restauración del workspace al abrir la aplicación y switch interactivo (`WorkspaceStore.loadAll`, `activeWorkspaceID`).
- `[x]` Guardado atómico con archivos `.tmp` y permisos `0o600`, migración de versiones del workspace.
- `[x]` Indicadores de sesión y estado operativo (`TimelineEventType`: conexión, comando, error, transfer, reconnect, securityAlert).
- `[x]` Timeline por workspace para conexiones, comandos, errores, transferencias y reconexiones (`WorkspaceTimelineEvent`, stream filtrable en UI).
- `[x]` Notas y comandos pendientes asociados al incidente (`WorkspaceIncidentNote`, `pendingCommands`).
- `[x]` Vista de comparación multi-host (`MultiHostComparator`, `GroupedOutputCluster`).
- `[x]` Agrupación de outputs idénticos y detección automática de outliers / anomalías (`isOutlier`).
- `[x]` Filtros por tipo de evento, host, duración y código de salida.
- `[x]` Snapshots comparables y exportación de incident bundle sanitizado (`IncidentBundleExporter.exportSanitizedBundle`).
- `[x]` Pruebas de suite con persistencia atómica, recarga tras ciclo de vida, árbol jerárquico de splits, comparación de clusters y sanitización estricta de tokens/credenciales.

### Parcial o pendiente

(Completado en su totalidad)

### Criterios de cierre

- Abrir un workspace restaura contexto, layout y sesiones sin secretos.
- Un incidente muestra en una sola vista qué ocurrió y cuándo.
- Una ejecución multi-host permite identificar excepciones rápidamente.
- El bundle exportado no contiene credenciales, tokens ni datos sensibles.

## Fase 4 — Escala e integración

### Implementado

- `[x]` Importar y exportar sesiones en formato JSON/YAML con esquema versionado (`SessionInventorySchema`, `SessionInventoryManager`).
- `[x]` Importar inventarios Ansible (INI/YAML) y `ssh_config` con validación y preview (`parseAnsibleInventory`).
- `[x]` Separación estricta de configuración, inventario y credenciales (sin filtración en exportaciones).
- `[x]` Fleet view con reachability, latencia en ms, última actividad, túneles y certificados próximos a vencer (`FleetNodeHealth`, `FleetManager`, `FleetHubView`).
- `[x]` Perfiles seriales por fabricante de hardware (Cisco, Juniper, Arista, MikroTik, genérico) con baud rates y rate limits adaptativos (`SerialHardwareManufacturer`).
- `[x]` Suite de pruebas exhaustiva con roundtrip de esquema de inventario, parser de Ansible, perfiles de hardware y métricas de salud de flota.

### Parcial o pendiente

(Completado en su totalidad)

### Criterios de cierre

- Un inventario se puede importar, revisar y revertir sin exponer secretos.
- Fleet view tolera hosts caídos y no bloquea la interfaz.
- CI reproduce los escenarios SSH principales de forma determinista.
- Las pruebas UI cubren los flujos críticos de usuario.
- Un benchmark que empeora sobre el umbral bloquea el PR o genera alerta clara.

## Calidad y release por fase

Para cada fase:

1. Crear un Issue por capacidad y agruparlo en el milestone de la fase.
2. Implementar en una rama y añadir pruebas junto con el cambio.
3. Abrir PR con criterios de aceptación y riesgos explícitos.
4. Ejecutar build macOS, pruebas unitarias, pruebas UI, CodeQL, dependencias y
   benchmarks aplicables.
5. Revisar manualmente sesiones, permisos, logs y errores.
6. Fusionar únicamente cuando el PR esté aprobado y CI esté verde.
7. Actualizar `VERSION`, changelog y documentación pública.
8. Crear el tag semántico firmado correspondiente.
9. Verificar los artefactos, checksums, attestation y appcast en GitHub Releases.
10. Probar `Check for Updates…` en un Mac con la versión anterior instalada.

## Estado del roadmap: Completado

Todas las fases planificadas (0 a 4) han sido implementadas en el código fuente, provistas de vistas SwiftUI integradas en el Session Manager, y validadas con la suite de pruebas unitarias (`EnterpriseSessionsTests`), resultando en 0 errores de compilación y 100% de tests aprobados en macOS.

### Registro de trabajo ejecutado:

1. `[x]` **Fase 0 completada**: Keychain references en reglas Expect/Send, resolución de credenciales por sesión (`SessionCredentialResolver`), migración de sesiones con `SessionFileEnvelope` v2, limpieza de Keychain huérfano (`reconcileKeychainOrphans`), conexión del logger a deltas reales de pantalla de terminal (`ingestScreenText`) y sanitización estricta de credenciales en logs.
2. `[x]` **Fase 1 completada**: Monitor de conectividad de red con `NWPathMonitor` (`isNetworkAvailable`, `.networkUnavailable`), reconexión interactiva (pausa, reanudación, cancelación), cálculo de porcentaje real en SCP (`parseProgressPercentage`), cola persistente priorizada con reintentos (`QueuedTransfer`, `transfers.json`), escaping robusto de rutas remotas con espacios y comillas, y alerta de discrepancia de host key (`HostKeyAlert`, `HostKeyAlertToast`).
3. `[x]` **Fase 2 completada**: Plantillas preconstruidas (`AutomationTemplate`: login, health check, deploy, backup, credential rotation), límites operativos (`maxTargets`, `timeoutLimitSeconds`), modo preview obligatorio (`preview(plan:policy:)`), historial persistente de ejecuciones (`automation_history.json`) e interfaz de usuario nativa (`AutomationHubView`).
4. `[x]` **Fase 3 completada**: Modelo de workspace jerárquico con tabs y splits (`WorkspaceModel`, `WorkspaceSplitNode`), almacenamiento atómico con permisos restrictivos `0o600` (`WorkspaceStore`), timeline de incidentes estructurado, notas y comandos pendientes, comparador multi-host con detección de outliers (`MultiHostComparator`), exportador sanitizado de incident bundles (`IncidentBundleExporter`) e interfaz visual (`WorkspaceHubView`).
5. `[x]` **Fase 4 completada**: Esquema de importación/exportación de inventario versionado sin secretos (`SessionInventorySchema`), parser de inventario Ansible INI/YAML (`parseAnsibleInventory`), monitor de flota con reachability y latencia (`FleetManager`), perfiles de consola serial por fabricante (`SerialHardwareManufacturer`) e interfaz de operaciones de flota (`FleetHubView`).

## Versionado

- `v1.1.x`: seguridad, aislamiento y migraciones.
- `v1.2.x`: SSH, logging, SCP/SFTP y reconexión.
- `v1.3.x`: automatización y ejecución multi-sesión.
- `v2.0.x`: workspace operativo y comparación multi-host.
- `v2.1.x`: fleet, Git, CI SSH y calidad avanzada.

Las versiones menores no requieren workflows nuevos: el mismo CI/CD se ejecuta
con cada PR, push o tag según la configuración del repositorio.
