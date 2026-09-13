<p align="center">
  <img src="images/icons/icon_256.png" width="128" alt="Spectre Pro icon">
</p>

<h1 align="center">Spectre Pro</h1>

<p align="center">
  <strong>Un terminal nativo para macOS, diseñado para mantener el trabajo técnico en movimiento.</strong>
</p>

<p align="center">
  <a href="https://github.com/skyones-0/spectrepro/releases/latest">Descargar</a>
  &nbsp;·&nbsp;
  <a href="#por-qué-spectre-pro">Producto</a>
  &nbsp;·&nbsp;
  <a href="#configuración">Configuración</a>
  &nbsp;·&nbsp;
  <a href="docs/ARCHITECTURE.md">Arquitectura</a>
  &nbsp;·&nbsp;
  <a href="SECURITY.md">Seguridad</a>
</p>

<p align="center">
  <a href="https://github.com/skyones-0/spectrepro/actions/workflows/test.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/skyones-0/spectrepro/test.yml?branch=main&style=flat-square&label=macOS%20CI" alt="macOS CI">
  </a>
  <a href="https://github.com/skyones-0/spectrepro/releases/latest">
    <img src="https://img.shields.io/github/v/release/skyones-0/spectrepro?display_name=tag&sort=semver&style=flat-square&label=release" alt="Latest release">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-111827?style=flat-square&logo=apple&logoColor=white" alt="macOS 13 or later">
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MPL--2.0-7c3aed?style=flat-square" alt="MPL 2.0 license">
  </a>
</p>

---

## Por qué Spectre Pro

Spectre Pro reúne el terminal, las sesiones y las herramientas que normalmente
terminan dispersas entre ventanas. Su núcleo está escrito en Zig; la experiencia
de macOS está construida con Swift, AppKit y Metal. El resultado es una aplicación
que se siente parte del sistema, sin esconder el control que importa.

| 🧭 Trabajo concentrado | ⚡ Superficie nativa | 🛡️ Seguridad visible |
| --- | --- | --- |
| Paneles, pestañas, tareas y comandos rápidos en un espacio de trabajo coherente. | Renderizado Metal, integración con Spaces, atajos y servicios de macOS. | Entrada segura, confirmación de portapapeles y permisos claros. |

## En la práctica

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>▣ Sesiones sin fricción</h3>
      <p>Divide el trabajo en paneles, conserva sesiones de larga duración y abre un Quick Terminal sin abandonar el contexto actual.</p>
    </td>
    <td width="50%" valign="top">
      <h3>⌘ Herramientas para operar</h3>
      <p>Gestiona tareas, comandos rápidos, procesos, puertos y notificaciones desde la propia aplicación.</p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>◌ Hecho para macOS</h3>
      <p>Menús, Services, AppleScript, App Intents, accesibilidad, pantalla completa y Spaces forman parte de la experiencia.</p>
    </td>
    <td width="50%" valign="top">
      <h3>◈ Personal sin ser frágil</h3>
      <p>Ajusta fuentes, temas, ligaduras, keybindings, shell integration e iconos sin convertir la configuración en una caja negra.</p>
    </td>
  </tr>
</table>

## Instalación

1. Descarga `SpectrePro.dmg` desde la [última versión](https://github.com/skyones-0/spectrepro/releases/latest).
2. Abre la imagen de disco y arrastra **Spectre Pro.app** a `/Applications`.
3. Inicia Spectre Pro desde Aplicaciones.

Las actualizaciones posteriores se gestionan desde **Spectre Pro → Check for Updates…**.

> **Nota para instalaciones personales:** las versiones se firman antes de su
> publicación, pero no están notarizadas con Developer ID. macOS puede pedir una
> confirmación durante el primer inicio.

## Configuración

La configuración vive donde debe vivir en macOS:

```text
~/.config/spectrepro/config
```

Spectre Pro crea el archivo al abrirse por primera vez. Si defines
`XDG_CONFIG_HOME`, usa esa ubicación. Los temas van en
`~/.config/spectrepro/themes`.

Después de editar la configuración, elige **Spectre Pro → Reload Configuration**.
No guardes secretos en archivos de configuración que compartas o subas a un
repositorio.

## Rendimiento con contexto

La velocidad no es una etiqueta: depende del Mac, la fuente, el tamaño de la
ventana, la carga de salida y el modo de compilación. Spectre Pro incluye
benchmarks para procesamiento de streams, secuencias de escape, Unicode,
compresión, snapshots, key encoding y estructuras de datos.

El panel **About Spectre Pro** muestra el uso residente de memoria y CPU del
proceso en tiempo real. Las comparaciones entre versiones se publican únicamente
cuando pueden reproducirse con la misma carga de trabajo y una línea base clara.

## Para desarrollar

Requisitos: macOS 13 o posterior, Xcode con SDK de macOS y Metal, y Zig `0.16.0`.

```bash
git clone https://github.com/skyones-0/spectrepro.git
cd spectrepro
zig build
open zig-out/SpectrePro.app
```

Para comprobar el núcleo:

```bash
zig build test
```

Para explorar el proyecto en Xcode, abre `macos/SpectrePro.xcodeproj`.

## Seguridad y licencia

Para reportar una vulnerabilidad, consulta [SECURITY.md](SECURITY.md). Spectre
Pro se distribuye bajo la licencia [Mozilla Public License 2.0](LICENSE). Las
licencias y avisos de componentes de terceros se conservan en el repositorio.
