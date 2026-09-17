# YubiKey PIV authentication in Spectre Pro

## Goal

Keep the PIV PIN flow inside Spectre Pro while preserving OpenSSH compatibility, hardware touch policy, and secret isolation.

## Current flow

1. Spectre Pro detects a compatible PIV token off the main UI path.
2. The session runtime starts one signed helper and one restricted socket per surface.
3. OpenSSH, SCP and SFTP use that session's `IdentityAgent` socket.
4. The helper requests the PIN through the active Spectre Pro sidebar and performs the PIV signature.

The current flow must not receive a PIN through command-line arguments, environment variables, terminal input, or logs.

## Production design

### Components

- `YubiKeyAuthenticationCoordinator`: `@MainActor` state machine owned by the session runtime.
- `YubiKeyPinRequest`: one-shot request containing only serial metadata, remaining retries, and a request identifier.
- `SpectreProYubiKeyAgent`: bundled, signed PIV SSH-agent helper with a restricted Unix-domain socket.
- `YubiKeyPINRequestView`: secure sidebar card for PIN entry and cancellation.
- `YubiKeyDetectedOverlay`: compact `key.circle.fill` overlay rendered below the existing session overlays when a YubiKey is detected.
- Bundled PIV agent: a minimal reproducible agent under `tools/SpectreProYubiKeyAgent`, pinned with `go.mod`/`go.sum`, that requests PINs through the helper protocol instead of opening an external dialog.

### State machine

`idle` → `detecting` → `waitingForPIN` → `waitingForTouch` → `authenticating` → `authenticated`

Failure states include `cancelled`, `timeout`, `tokenRemoved`, `wrongPIN`, and `unavailable`.

### Security requirements

- Never persist the PIN.
- Never include the PIN in process arguments, environment variables, terminal input, logs, crash reports, or analytics.
- Bind the per-session agent and prompt sockets below `~/Library/Application Support/co.skyones.spectrepro/yubikey/<surface-id>/` with mode `0600`.
- Authenticate the helper using a per-launch random capability.
- Accept exactly one pending request and expire it after a short timeout.
- Clear the SwiftUI field immediately after submission and never persist the PIN.
- Clear the UI field when the request completes.
- Keep the external fallback available when the helper is unavailable.

### YubiKey detection overlay

- Detect YubiKey presence asynchronously and off the main UI path.
- Show `key.circle.fill` below the existing secure-input, sidebar, SFTP, serial, and task overlays.
- Keep the overlay hidden when no compatible YubiKey is present.
- Use the overlay as a status/entry point only; it must not expose the PIN or claim that a touch is pending unless the authentication helper reports that state.
- Remove the overlay immediately when the token is removed or detection becomes unavailable.
- Preserve the current overlay spacing and collision-avoidance rules.

### Reproducibility

- Pin Go module versions and checksums in `tools/SpectreProYubiKeyAgent/go.sum`.
- Build the helper as part of the release workflow.
- Embed it in `SpectrePro.app/Contents/Helpers`.
- Sign it with the same distribution identity as the app.
- Verify its code signature before launch in non-debug builds.
- Build and sign the helper before signing the app in `.github/workflows/release-tag.yml`.
- Add hardware smoke coverage for slot `9A`; the app fallback asks for confirmation before using the external provider.

## Delivery order

1. Add protocol types, capability-authenticated socket, and unit tests.
2. Add the coordinator and sidebar UI without changing SSH behavior.
3. Add asynchronous YubiKey detection and the `key.circle.fill` overlay.
4. Add the pinned helper and patched agent build target.
5. Enable the helper for PIV sessions and retain external fallback.
6. Test real PIN, wrong PIN, touch-required slot, token removal, cancellation, reconnect, and concurrent sessions.
7. Run a hardware validation on the YubiKey slot `9A` before release.

## Acceptance criteria

- The user sees the PIN request in the active session sidebar.
- A detected YubiKey shows `key.circle.fill` below the existing overlays and disappears when the token is removed.
- The app shows `Waiting for PIN` and `Touch YubiKey` without guessing the hardware state.
- The PIN is never written to disk or logs.
- A cancelled or expired request cannot authenticate later.
- Two sessions cannot consume each other's PIN request.
- Removing the helper or YubiKey produces a recoverable error and the external fallback remains available.
