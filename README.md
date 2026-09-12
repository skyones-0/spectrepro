# Spectre Pro

**Spectre Pro** is a native macOS terminal and infrastructure console for
operators who need a fast workspace without giving up context, safety, or
native system integration.

Built with a Zig terminal core, a Metal renderer, and a Swift/AppKit macOS
application, Spectre Pro is designed for sustained interactive work: operating
production systems, following high-volume logs, managing long-lived sessions,
and moving between focused and full-screen workflows.

## Product philosophy

Spectre Pro is guided by four principles:

1. **Keep the operator in flow.** Terminal, sessions, quick commands, tasks,
   and split views belong in one keyboard-friendly workspace.
2. **Make safety visible.** Secure input, confirmation flows, clear session
   state, and native macOS permissions should make consequential actions easier
   to understand.
3. **Respect the platform.** Menus, services, accessibility, keyboard
   shortcuts, fullscreen behavior, and Spaces are macOS features—not
   afterthoughts.
4. **Measure before claiming speed.** Performance claims are only meaningful
   when the workload, hardware, build mode, and measurement method are
   reproducible.

## Highlights

- Metal-accelerated terminal rendering backed by a native Zig core.
- Tabs, panes, split layouts, window styles, and a Quick Terminal for focused
  work across macOS Spaces.
- Session management, command notifications, a task overlay, and quick-command
  libraries for repeatable operator workflows.
- Configurable themes, fonts, keybindings, shell integration, services, and
  AppleScript/App Intents integration.
- Secure keyboard input, clipboard confirmation, keep-awake controls, hardware
  access, port detection, and process monitoring.
- Native macOS menus, accessibility support, custom app icons, and support for
  system appearance changes.

## Requirements

- macOS 13 or later
- Xcode with the macOS SDK and Metal toolchain
- Zig 0.16.0

## Build and run

```bash
zig build
open zig-out/SpectrePro.app
```

To install a local debug build:

```bash
ditto zig-out/SpectrePro.app "/Applications/Spectre Pro.app"
open "/Applications/Spectre Pro.app"
```

## Tests

Run the Zig test suite:

```bash
zig build test
```

The macOS project also contains unit and UI test targets. Use the build helper
in `macos/build.nu` or open `macos/SpectrePro.xcodeproj` in Xcode to run the
appropriate target for your configuration.

## Performance and stress testing

The repository includes a benchmark executable for terminal stream processing,
escape-sequence parsing, Unicode handling, compression, snapshots, key
encoding, and data-structure workloads. Build it in an optimized mode before
recording results:

```bash
zig build -Demit-bench -Doptimize=ReleaseFast -Demit-macos-app=false
./zig-out/bin/spectrepro-bench --help
```

Benchmark sources live in `src/benchmark`. For any published comparison,
record the following alongside the output:

- Mac model, chip, RAM, macOS version, and power mode
- Spectre Pro commit, Zig version, and build options
- Exact benchmark command, corpus, warm-up procedure, and repetitions
- Median, dispersion, and the baseline or previous revision being compared

This policy makes regressions actionable and keeps performance reports useful
across different machines and releases.

## Releases and updates

Create and push a signed tag such as `v1.0.3` to trigger the personal macOS
release workflow. It builds an unsigned app, creates a Sparkle-signed
`appcast.xml`, and publishes the DMG, ZIP, and appcast in the
[Spectre Pro repository](https://github.com/skyones-0/spectrepro).

This personal distribution does not require a paid Apple Developer membership,
but it is neither Developer ID signed nor notarized. Install the first release
manually and approve it in macOS Privacy & Security if Gatekeeper warns about
an unidentified developer. Later releases are verified by Sparkle's update
signature before installation.

### Publish a new version

Use semantic versions with three components: `vMAJOR.MINOR.PATCH`. For example,
to publish version `1.0.3`:

```bash
git commit -am "Describe the change"
git push origin main

git tag -s v1.0.3 -m "Spectre Pro 1.0.3"
git push origin v1.0.3
```

Pushing to `main` runs macOS CI. Pushing the signed tag runs the personal
release workflow, which builds the app and uploads the DMG, ZIP, and signed
appcast to GitHub Releases. No new workflow is required for later versions.

### Automation triggers

- Every push runs macOS CI; pull requests also run CI, CodeQL, workflow lint,
  and dependency review.
- Pushes to `main` run CodeQL and workflow lint.
- Signed version tags run the release workflow, which publishes the DMG, ZIP,
  appcast, SHA-256 checksums, SBOM, and attestations, then verifies the
  published assets.
- Benchmarks run weekly or manually. They compare the median wall time against
  the previous benchmark artifact and warn when it regresses by more than 10%.

## License

Spectre Pro is licensed under the Mozilla Public License 2.0. See
[LICENSE](LICENSE) for the complete terms and required notices.
