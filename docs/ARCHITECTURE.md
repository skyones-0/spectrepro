# Spectre Pro Architecture

Spectre Pro is a macOS-first terminal application. The repository keeps the
terminal engine separate from the Apple application layer so each layer can be
tested and changed without duplicating terminal behavior.

## Repository boundaries

| Path | Responsibility |
| --- | --- |
| `macos/Sources/App` | Application lifecycle, commands, menus, and startup. |
| `macos/Sources/Features` | User-facing macOS features, grouped by product capability. |
| `macos/Sources/SpectrePro` | Swift bridge to the Zig C API and terminal surface integration. |
| `macos/Tests` and `macos/SpectreProUITests` | Unit, integration, and UI tests for the macOS application. |
| `src/terminal` | Terminal state, parsing, scrollback, rendering input, and snapshots. |
| `src/config`, `src/input`, `src/termio`, `src/renderer` | Core domain packages with explicit responsibilities. |
| `src/build` | Zig build steps and release artifacts. |
| `pkg` | Third-party or independently reusable dependencies. |

## Dependency direction

The macOS layer depends on `SpectreProKit`; it does not reimplement terminal
state. `SpectreProKit` exposes the Zig engine through its C API. The engine may
depend on domain packages, but domain packages must not import macOS UI code.

New macOS work belongs in an existing feature folder when it extends that
capability. Create a new folder only for an independent product capability.
Shared AppKit helpers belong in `macos/Sources/Helpers` only when they are used
by more than one feature.

## macOS support policy

The release product and CI target macOS. Cross-platform directories remain in
the engine because they provide shared terminal behavior and upstream-compatible
build definitions. Do not remove a non-macOS package merely because it is not
shipped in the macOS app: first prove it is absent from the macOS dependency
graph and remove its build dependency and tests in the same change.

External dependency URLs and upstream copyright notices are supply-chain and
license metadata, not product names. Replace a dependency URL only after a
verified mirror with the same immutable archive and checksum is available.

## Configuration

The canonical user configuration is `$XDG_CONFIG_HOME/spectrepro/config`, which
defaults to `~/.config/spectrepro/config`. Spectre Pro creates this template on
first launch when no configuration exists. On macOS, it copies an existing
Application Support configuration to that canonical path and keeps the source
file as a backup. The prior `config.spectrepro` name remains readable for
compatibility.

## Change rules

- Keep one feature or domain responsibility per source file when practical.
- Extract a file when it owns a protocol implementation or a cohesive service.
- Do not split terminal-engine structs solely because they are long; preserve
  invariants and colocated tests until a real domain boundary exists.
- Add or update tests in the matching test directory with every behavior change.
