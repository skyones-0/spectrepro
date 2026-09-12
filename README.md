# Spectre Pro

**Spectre Pro** is a native terminal and infrastructure workspace for macOS.
It combines a Zig terminal core, Metal rendering, and a Swift/AppKit interface
so operators can work with shells, long-running sessions, logs, and repeatable
commands without leaving the macOS environment.

[Releases](https://github.com/skyones-0/spectrepro/releases) ·
[Security policy](SECURITY.md) ·
[Architecture](docs/ARCHITECTURE.md) ·
[CI status](https://github.com/skyones-0/spectrepro/actions/workflows/test.yml)

## Built for focused operations

Spectre Pro is designed around four practical principles:

1. **Keep the operator in flow.** Tabs, panes, sessions, tasks, quick
   commands, and a Quick Terminal keep related work in one keyboard-friendly
   workspace.
2. **Make safety visible.** Secure keyboard entry, clipboard confirmation,
   session state, and native permission flows make consequential actions easier
   to understand.
3. **Respect macOS.** Menus, Services, accessibility, shortcuts, Spaces,
   fullscreen, AppleScript, and App Intents are part of the product—not a
   compatibility layer.
4. **Measure before claiming speed.** Performance comparisons require a
   reproducible workload, hardware description, build mode, and baseline.

## Capabilities

- Metal-accelerated terminal rendering with a native Zig core.
- Tabs, split panes, window styles, and a Quick Terminal for work across
  macOS Spaces.
- Session management, command notifications, task overlay, quick-command
  libraries, process monitoring, and port detection.
- Configurable fonts, themes, keybindings, shell integration, custom icons,
  Services, AppleScript, and App Intents.
- Secure input, clipboard confirmation, keep-awake controls, and native
  accessibility support.

## Install

### Personal release

1. Download `SpectrePro.dmg` from the
   [latest release](https://github.com/skyones-0/spectrepro/releases/latest).
2. Open the disk image and drag `Spectre Pro.app` to `/Applications`.
3. Open **Spectre Pro** from Applications.

This project uses personal distribution: releases are not Developer ID signed
or notarized. macOS may ask you to approve the first launch in **System
Settings → Privacy & Security**. Once installed, **Spectre Pro → Check for
Updates…** uses Sparkle metadata to verify and install later releases.

### Build from source

Requirements:

- macOS 13 or later
- Xcode with the macOS SDK and Metal toolchain
- Zig `0.16.0`

```bash
git clone https://github.com/skyones-0/spectrepro.git
cd spectrepro
zig build
open zig-out/SpectrePro.app
```

For a local debug installation:

```bash
ditto zig-out/SpectrePro.app "/Applications/Spectre Pro.app"
open "/Applications/Spectre Pro.app"
```

## Configuration

On first launch, Spectre Pro creates its canonical configuration file at:

```text
~/.config/spectrepro/config
```

`$XDG_CONFIG_HOME` is respected when it is set. Edit this file, then select
**Spectre Pro → Reload Configuration** to apply supported changes. Theme files
belong in `~/.config/spectrepro/themes`.

On macOS, Spectre Pro copies an existing Application Support configuration to
the canonical XDG path on first launch and retains the original file as a
backup. The older `~/.config/spectrepro/config.spectrepro` path remains
readable for compatibility. Do not place secrets in any configuration file
committed to source control.

## Quality and performance

Run the Zig test suite:

```bash
zig build test
```

Open `macos/SpectrePro.xcodeproj` in Xcode, or use `macos/build.nu`, to run the
macOS unit and UI targets for the selected configuration.

The benchmark executable covers terminal stream processing, escape-sequence
parsing, Unicode, compression, snapshots, key encoding, and data structures:

```bash
zig build -Demit-bench -Doptimize=ReleaseFast -Demit-macos-app=false
./zig-out/bin/spectrepro-bench --help
```

When comparing revisions, record the Mac model, chip, RAM, macOS version,
power mode, commit, Zig version, build options, exact command, warm-up, and
median result. The scheduled benchmark workflow compares its median with the
previous successful baseline and warns on a regression greater than 10%.

## Delivery pipeline

GitHub Actions protects the project at each stage:

| Event | What runs | Outcome |
| --- | --- | --- |
| Pull request | macOS build and tests, CodeQL, workflow lint, dependency review | A reviewed quality gate before `main` |
| Push to `main` | macOS CI, CodeQL, workflow lint | Continuous validation of the integration branch |
| Signed `vX.Y.Z` tag | Release build, Sparkle appcast, checksums, SBOM, provenance attestations | A GitHub Release with update assets |
| Weekly or manual dispatch | Benchmarks | A performance comparison against the previous run |

The release workflow publishes `SpectrePro.dmg`, a ZIP archive, `appcast.xml`,
`SHA256SUMS.txt`, and an SPDX SBOM. It downloads those published assets again
and verifies their checksums and update metadata before completing.

## Publish a release

Use semantic versions with three components. For example, after updating the
versioned project files for `1.0.3` and merging the change into `main`:

```bash
git switch main
git pull --ff-only origin main
git tag -s v1.0.3 -m "Spectre Pro 1.0.3"
git push origin v1.0.3
```

The signed tag starts the release workflow. Wait for **Personal macOS Release**
to finish successfully, then verify the published files in GitHub Releases and
test **Check for Updates…** once on a Mac with the prior release installed.
No new workflow is necessary for the next version—only a new signed version
tag.

## Project structure

- `macos/Sources/Features` — product features grouped by responsibility.
- `macos/Sources/App` — application lifecycle, menu, and window coordination.
- `macos/Sources/SpectrePro/Surface View` — AppKit terminal surface adapters.
- `src` — Zig terminal engine, renderer, configuration, and platform services.
- `docs/ARCHITECTURE.md` — source boundaries and macOS-first scope policy.
- `.github/workflows` — CI, security, benchmark, and release automation.

## Security and licensing

Report vulnerabilities privately according to [SECURITY.md](SECURITY.md).
Spectre Pro is licensed under the Mozilla Public License 2.0; see
[LICENSE](LICENSE). Upstream notices and third-party licenses remain in the
repository where required.
