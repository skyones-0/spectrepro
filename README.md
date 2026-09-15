<p align="center">
  <img src="images/icons/icon_256.png" width="128" alt="Spectre Pro icon">
</p>

<h1 align="center">Spectre Pro</h1>

<p align="center">
  <strong>The native macOS terminal for work that does not fit in one window.</strong>
</p>

<p align="center">
  <a href="https://github.com/skyones-0/spectrepro/releases/latest">Download</a>
  &nbsp;·&nbsp;
  <a href="#what-you-can-do">Features</a>
  &nbsp;·&nbsp;
  <a href="docs/GUIA_FUNCIONES_AVANZADAS.md">Manual Técnico Avanzado</a>
  &nbsp;·&nbsp;
  <a href="#configuration">Configuration</a>
  &nbsp;·&nbsp;
  <a href="docs/ARCHITECTURE.md">Architecture</a>
  &nbsp;·&nbsp;
  <a href="SECURITY.md">Security</a>
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

## A terminal with a sense of place

Spectre Pro is built for the moments when a terminal becomes the center of the
job: tracing a production issue, keeping a deployment open, following logs,
comparing output, or moving between several systems without losing your place.

The terminal core is written in Zig. The macOS application is built with Swift,
AppKit, and Metal. That split keeps the rendering path fast while making windows,
menus, keyboard shortcuts, accessibility, and system integrations feel native.

<table>
  <tr>
    <td width="33%" valign="top">
      <h3>▣ Keep context</h3>
      <p>Tabs, split panes, long-running sessions, and a Quick Terminal keep related work together instead of scattered across windows.</p>
    </td>
    <td width="33%" valign="top">
      <h3>⌘ Stay in flow</h3>
      <p>Quick commands, task views, process details, port detection, and notifications reduce the repeated work around the prompt.</p>
    </td>
    <td width="33%" valign="top">
      <h3>◈ Trust the surface</h3>
      <p>Secure input, clipboard confirmation, visible permissions, and native update checks make consequential actions easier to understand.</p>
    </td>
  </tr>
</table>

## What you can do

| Area | Spectre Pro capabilities |
| --- | --- |
| **Workspaces** | Tabs, split panes, configurable window styles, fullscreen support, and a Quick Terminal that can follow you across Spaces. |
| **Sessions** | Keep shell sessions open, monitor background work, receive command-completion notifications, and inspect active processes. |
| **Command tools** | Build reusable quick-command libraries, manage tasks, identify local ports, and keep commonly used operations close at hand. |
| **Appearance** | Choose fonts, themes, ligatures, cursor behavior, keybindings, shell integration, and application icons. |
| **macOS integration** | Services, AppleScript, App Intents, accessibility, native menus, standard shortcuts, and system window behavior. |
| **Safety controls** | Secure Keyboard Entry, clipboard confirmation, keep-awake controls, and clear system permission flows. |

### Made for the work between commands

Spectre Pro does not treat the terminal as a blank rectangle. It keeps useful
state around it: command history and completion signals, session management,
background activity, searchable output, transfer activity, and configurable
shortcuts. The goal is simple: fewer context switches while the work is still
in progress.

## Native by design

Spectre Pro follows macOS conventions instead of recreating them:

- **Windows and Spaces** — Use the window behavior, titlebar styles, fullscreen,
  and Quick Terminal placement that suit your desktop.
- **Keyboard-first operation** — Standard shortcuts, configurable keybindings,
  and a command palette keep frequent actions close.
- **System services** — Work with macOS Services, AppleScript, App Intents, and
  accessibility rather than routing around them.
- **Rendering** — A Metal-backed terminal surface is paired with a Zig core for
  terminal emulation, parsing, configuration, and platform services.

## Performance without theatre

Performance claims need a workload, a machine, and a baseline. Spectre Pro
includes benchmarks for terminal stream processing, escape sequences, Unicode,
compression, snapshots, key encoding, and data structures. Comparative results
are useful only when those conditions are held constant.

**About Spectre Pro** shows two live, local measurements for the running app:

- **Resident memory** — memory currently retained by the process.
- **Process CPU** — CPU time sampled over the most recent second.

These measurements stay on your Mac. They are not usage analytics and are not
sent to a remote service.

## Install

1. Download `SpectrePro.dmg` from the [latest release](https://github.com/skyones-0/spectrepro/releases/latest).
2. Open the disk image and drag **Spectre Pro.app** to `/Applications`.
3. Launch **Spectre Pro** from Applications.

Use **Spectre Pro → Check for Updates…** to look for later releases.

> **Personal releases:** release builds are signed before publication but are
> not Developer ID notarized. macOS may ask for confirmation on first launch.

## Configuration

Spectre Pro creates its configuration file automatically on first launch:

```text
~/.config/spectrepro/config
```

`XDG_CONFIG_HOME` is respected when set. Put theme files in
`~/.config/spectrepro/themes`, then choose **Spectre Pro → Reload Configuration**
to apply supported changes. Do not place secrets in configuration files that you
share or commit.

## Build from source

Requirements: macOS 13 or later, Xcode with the macOS SDK and Metal toolchain,
and Zig `0.16.0`.

```bash
git clone https://github.com/skyones-0/spectrepro.git
cd spectrepro
zig build
open zig-out/SpectrePro.app
```

Run the core test suite with:

```bash
zig build test
```

Open `macos/SpectrePro.xcodeproj` to work on the macOS application in Xcode.

## Security and license

Read [SECURITY.md](SECURITY.md) to report a vulnerability. Spectre Pro is
licensed under the [Mozilla Public License 2.0](LICENSE). Required upstream and
third-party notices remain in the repository.
