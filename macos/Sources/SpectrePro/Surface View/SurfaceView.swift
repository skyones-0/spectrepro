import SwiftUI
import UserNotifications
import SpectreProKit
import System

extension SpectrePro {
    struct SurfaceWrapper: View {
        // The surface to create a view for. This must be created upstream. As long as this
        // remains the same, the surface that is being rendered remains the same.
        @ObservedObject var surfaceView: SurfaceView

        // True if this surface is part of a split view. This is important to know so
        // we know whether to dim the surface out of focus.
        var isSplit: Bool = false

        // Maintain whether our view has focus or not
        @FocusState private var surfaceFocus: Bool

        // Maintain whether our window has focus (is key) or not
        @State private var windowFocus: Bool = true

        // Observe SecureInput to detect when its enabled
        @ObservedObject private var secureInput = SecureInput.shared

        // Monitor background processes on this surface
        @StateObject private var processMonitor = TerminalProcessMonitor()

        // Serial device watcher
        @ObservedObject private var serialWatcher = SerialDeviceWatcher.shared

        // Background tasks manager
        @ObservedObject private var taskManager = BackgroundTaskManager.shared

        // Session logger observer
        @ObservedObject private var sessionLogger: SessionLogger

        // Expect / Send automation engine
        @ObservedObject private var expectSend: ExpectSendEngine

        // Per-surface YubiKey authentication state
        @ObservedObject private var sessionRuntimeObserved: RemoteSessionRuntime
        @ObservedObject private var yubikeyObserved: YubiKeyAuthenticationCoordinator

        // Ephemeral HUD toast for copied command output
        @State private var copiedHudMessage: String?
        @State private var isSFTPBrowserPresented = false

        @EnvironmentObject private var spectrepro: SpectrePro.App
        @Environment(\.spectreproLastFocusedSurface) private var lastFocusedSurface

        init(surfaceView: SurfaceView, isSplit: Bool = false) {
            self.surfaceView = surfaceView
            self.isSplit = isSplit
            let runtime = SessionRuntimeRegistry.shared.runtime(for: surfaceView.id)
            _sessionLogger = ObservedObject(wrappedValue: runtime.logger)
            _expectSend = ObservedObject(wrappedValue: runtime.automation)
            _sessionRuntimeObserved = ObservedObject(wrappedValue: runtime)
            _yubikeyObserved = ObservedObject(wrappedValue: runtime.yubikey)
        }

        private var sessionRuntime: RemoteSessionRuntime {
            sessionRuntimeObserved
        }

        private var isSSHSession: Bool {
            sessionRuntime.session?.sessionType.lowercased() == "ssh"
        }

        private var isQuickTerminal: Bool {
            surfaceView.window?.windowController is QuickTerminalController
        }

        /// Keep terminal cells clear of the floating control stack at the trailing edge.
        /// A terminal is a rectangular grid, so the only way to prevent text from
        /// appearing behind those controls is to reserve their column from the
        /// renderer rather than merely drawing the controls above it.
        private var trailingOverlayGutterWidth: CGFloat {
            // Controls are 35 pt wide and sit 4 pt from the edge. Keep a small
            // 3 pt clearance between the terminal grid and the control stack.
            isQuickTerminal ? 0 : 42
        }

        private var isFocusedSurface: Bool {
            if surfaceView.focused { return true }
            if surfaceFocus { return true }
            if let last = lastFocusedSurface?.value {
                return last === surfaceView
            }
            if let win = surfaceView.window {
                return win.isKeyWindow
            }
            return true
        }

        var body: some View {
            let center = NotificationCenter.default

            ZStack {
                // We use a GeometryReader to get the frame bounds so that our metal surface
                // is up to date. See TerminalSurfaceView for why we don't use the NSView
                // resize callback.
                GeometryReader { geo in
                    let terminalSize = CGSize(
                        width: max(0, geo.size.width - trailingOverlayGutterWidth),
                        height: geo.size.height
                    )
                    let pubBecomeKey = center.publisher(for: NSWindow.didBecomeKeyNotification)
                    let pubResign = center.publisher(for: NSWindow.didResignKeyNotification)

                    SurfaceRepresentable(view: surfaceView, size: terminalSize)
                        .frame(width: terminalSize.width, height: terminalSize.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .focused($surfaceFocus)
                        .focusedValue(\.spectreproSurfacePwd, surfaceView.pwd)
                        .focusedValue(\.spectreproSurfaceView, surfaceView)
                        .focusedValue(\.spectreproSurfaceCellSize, surfaceView.cellSize)
                        .onReceive(pubBecomeKey) { notification in
                            guard let window = notification.object as? NSWindow else { return }
                            guard let surfaceWindow = surfaceView.window else { return }
                            windowFocus = surfaceWindow == window
                        }
                        .onReceive(pubResign) { notification in
                            guard let window = notification.object as? NSWindow else { return }
                            guard let surfaceWindow = surfaceView.window else { return }
                            if surfaceWindow == window {
                                windowFocus = false
                            }
                        }

                    // If our geo size changed then we show the resize overlay as configured.
                    if let surfaceSize = surfaceView.surfaceSize {
                        SurfaceResizeOverlay(
                            geoSize: terminalSize,
                            size: surfaceSize,
                            overlay: spectrepro.config.resizeOverlay,
                            position: spectrepro.config.resizeOverlayPosition,
                            duration: spectrepro.config.resizeOverlayDuration,
                            focusInstant: surfaceView.focusInstant)

                    }
                }
                .spectreproSurfaceView(surfaceView)

                // Progress report
                if let progressReport = surfaceView.progressReport, progressReport.state != .remove {
                    VStack(spacing: 0) {
                        SurfaceProgressBar(report: progressReport)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }

                // Readonly indicator badge
                if surfaceView.readonly {
                    ReadonlyBadge {
                        surfaceView.toggleReadonly(nil)
                    }
                }

                // Show key state indicator for active key tables and/or pending key sequences
                KeyStateIndicator(
                    keyTables: surfaceView.keyTables,
                    keySequence: surfaceView.keySequence
                )
                .zIndex(1)

                VStack(spacing: 0) {
                    // If we have a URL from hovering a link, we show that.
                    if let url = surfaceView.hoverUrl {
                        URLHoverBanner(url: url)
                    }

                    // Show a bar to indicate a child process has exited.
                    if let msg = surfaceView.childExitedMessage {
                        ChildExitedMessageBar(msg: msg)
                            .font(.system(size: min(surfaceView.cellSize.height * 0.8, 30)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                // Top-Right Overlays: Secure Input & Background Processes
                topRightOverlays

                // Ephemeral Floating Alerts (Serial Device, Local Server Port, Copied HUD)
                ephemeralAlerts

                // Search overlay
                if let searchState = surfaceView.searchState {
                    SurfaceSearchOverlay(
                        surfaceView: surfaceView,
                        searchState: searchState,
                        onClose: {
                            surfaceView.endSearch()
                        }
                    )
                }

                // Show bell border if enabled
                if spectrepro.config.bellFeatures.contains(.border) {
                    BellBorderOverlay(bell: surfaceView.bell)
                }

                // Show a highlight effect when this surface needs attention
                HighlightOverlay(highlighted: surfaceView.highlighted)

                // If our surface is not healthy, then we render an error view over it.
                if !surfaceView.healthy {
                    Rectangle().fill(spectrepro.config.backgroundColor)
                    SurfaceRendererUnhealthyView()
                } else if surfaceView.error != nil {
                    Rectangle().fill(spectrepro.config.backgroundColor)
                    SurfaceErrorView()
                }

                // If we're part of a split view and don't have focus, we put a semi-transparent
                // rectangle above our view to make it look unfocused. We include the last
                // focused surface so this still works while SwiftUI focus is temporarily nil.
                if isSplit && !isFocusedSurface {
                    let overlayOpacity = spectrepro.config.unfocusedSplitOpacity
                    if overlayOpacity > 0 {
                        Rectangle()
                            .fill(spectrepro.config.unfocusedSplitFill)
                            .allowsHitTesting(false)
                            .opacity(overlayOpacity)
                    }
                }

                // Grab handle for dragging the window. We want this to appear at the very
                // top Z-index os it isn't faded by the unfocused overlay.
                SurfaceGrabHandle(
                    surfaceView: surfaceView,
                    dragHandle: spectrepro.config.dragHandle,
                )
            }
            .onAppear {
                processMonitor.setSurfaceView(surfaceView)
                processMonitor.isFocused = isFocusedSurface && windowFocus
            }
            .onChange(of: surfaceView) { newView in
                processMonitor.setSurfaceView(newView)
            }
            .onChange(of: isFocusedSurface) { focused in
                processMonitor.isFocused = focused && windowFocus
            }
            .onChange(of: windowFocus) { winFocused in
                processMonitor.isFocused = isFocusedSurface && winFocused
            }
            .onReceive(NotificationCenter.default.publisher(for: .spectreproCopiedOutput)) { notif in
                guard let targetUUID = notif.userInfo?["surfaceUUID"] as? UUID,
                      targetUUID == surfaceView.id else { return }
                copiedHudMessage = "Copied command output"
                Task {
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    if copiedHudMessage == "Copied command output" {
                        copiedHudMessage = nil
                    }
                }
            }
            .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                guard sessionLogger.isRecording || (isFocusedSurface && windowFocus) else { return }
                if sessionLogger.isRecording {
                    let screenText = surfaceView.readScreenText()
                    sessionLogger.ingestScreenText(screenText)
                }
                guard isFocusedSurface && windowFocus else { return }
                let text = surfaceView.readVisibleText()
                if KeywordHighlighter.shared.isEnabled {
                    KeywordHighlighter.shared.scan(text: text)
                }
                // Detect download triggers: SPECTRE_DOWNLOAD:<path> or SPECTREPRO_DOWNLOAD:<path>
                let downloadMarker = text.range(of: "SPECTRE_DOWNLOAD:") ?? text.range(of: "SPECTREPRO_DOWNLOAD:")
                if let range = downloadMarker {
                    let after = text[range.upperBound...]
                    let candidate = after.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !candidate.isEmpty && sessionRuntime.transfers.activeTransfer == nil {
                        sessionRuntime.transfers.downloadFile(remotePath: candidate, surface: surfaceView)
                    }
                }
            }
        }

        @ViewBuilder
        private var topRightOverlays: some View {
            VStack(spacing: 8) {
                if spectrepro.config.secureInputIndication &&
                    secureInput.enabled &&
                    isFocusedSurface &&
                    windowFocus {
                    SecureInputOverlay()
                }

                if !isQuickTerminal && isFocusedSurface && windowFocus {
                    SidebarToggleOverlay(
                        isShowing: QuickCommandsState.shared.isShowing,
                        onToggle: {
                            QuickCommandsState.shared.toggle()
                        }
                    )
                }

                if isSSHSession && isFocusedSurface && windowFocus {
                    SFTPOpenOverlay {
                        NotificationCenter.default.post(
                            name: .spectreproOpenSFTPBrowser,
                            object: surfaceView,
                            userInfo: ["surfaceUUID": surfaceView.id]
                        )
                    }
                }

                if isSSHSession &&
                    sessionRuntime.yubikey.isYubiKeyPresent &&
                    isFocusedSurface && windowFocus {
                    YubiKeyDetectedOverlay(state: sessionRuntime.yubikey.state)
                }

                if isSSHSession &&
                    !QuickCommandsState.shared.isShowing &&
                    isFocusedSurface && windowFocus {
                    switch sessionRuntime.yubikey.state {
                    case .waitingForPIN(let request):
                        YubiKeyPINRequestView(
                            request: request,
                            onSubmit: { pin in
                                sessionRuntime.yubikey.acceptPIN(pin)
                            },
                            onCancel: {
                                sessionRuntime.yubikey.cancelPIN()
                            })
                            .frame(maxWidth: 320)
                    case .waitingForTouch:
                        YubiKeyTouchRequestView()
                            .frame(maxWidth: 320)
                    default:
                        EmptyView()
                    }
                }

                if surfaceView.serialDevice != nil && isFocusedSurface && windowFocus {
                    SerialExitOverlay {
                        NotificationCenter.default.post(
                            name: SpectrePro.Notification.spectreproReplaceSurface,
                            object: surfaceView,
                            userInfo: [
                                SpectrePro.Notification.NewSurfaceConfigKey: SpectrePro.SurfaceConfiguration()
                            ]
                        )
                    }
                }

                if isFocusedSurface && windowFocus && (!processMonitor.backgroundJobs.isEmpty || taskManager.activeCount > 0) {
                    BackgroundProcessOverlay(
                        jobs: processMonitor.backgroundJobs,
                        tasks: taskManager.activeTasks,
                        onKillJob: { job in
                            processMonitor.terminateJob(job)
                        },
                        onCancelTask: { task in
                            taskManager.stop(id: task.id)
                        }
                    )
                }

                if isFocusedSurface && windowFocus && sessionLogger.isRecording {
                    SessionRecordingIndicator(logger: sessionLogger)
                }

                if isFocusedSurface && windowFocus {
                    SSHTransferOverlay(manager: sessionRuntime.transfers)
                }

                if isFocusedSurface && windowFocus, let status = expectSend.currentStatus {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text(status)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 10)
            .padding(.trailing, 4)
            .onReceive(NotificationCenter.default.publisher(for: .spectreproOpenSFTPBrowser)) { notification in
                guard let targetUUID = notification.userInfo?["surfaceUUID"] as? UUID,
                      targetUUID == surfaceView.id else { return }
                isSFTPBrowserPresented = true
            }
            .sheet(isPresented: $isSFTPBrowserPresented) {
                if let context = sessionRuntime.transfers.context(for: surfaceView.id) {
                    SFTPBrowserView(context: context)
                } else {
                    Text("No active SSH session")
                        .padding(40)
                }
            }
        }

        @ViewBuilder
        private var ephemeralAlerts: some View {
            VStack(spacing: 8) {
                if let serial = serialWatcher.activeAlert, isFocusedSurface {
                    SerialDeviceToast(
                        device: serial,
                        baudRate: $serialWatcher.selectedBaudRate,
                        onConnect: { dev, baud in
                            var config = SerialConnectionConfig.default(for: dev.bsdPath, name: dev.name)
                            config.baudRate = baud
                            let serial = SpectrePro.SurfaceConfiguration(serial: config)
                            NotificationCenter.default.post(
                                name: SpectrePro.Notification.spectreproReplaceSurface,
                                object: surfaceView,
                                userInfo: [SpectrePro.Notification.NewSurfaceConfigKey: serial]
                            )
                            serialWatcher.dismissAlert()
                        },
                        onDismiss: {
                            serialWatcher.dismissAlert()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }

                if let portInfo = processMonitor.activePortAlert, isFocusedSurface {
                    LocalPortToast(
                        portInfo: portInfo,
                        onDismiss: {
                            processMonitor.dismissPortAlert()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }

                if let cmdAlert = processMonitor.activeCommandAlert, isFocusedSurface {
                    CommandFinishedToast(
                        alert: cmdAlert,
                        onDismiss: {
                            processMonitor.dismissCommandAlert()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }

                if let msg = copiedHudMessage, isFocusedSurface {
                    CopiedHudToast(message: msg)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }

                if let hostAlert = sessionRuntime.transfers.lastHostKeyAlert, isFocusedSurface {
                    HostKeyAlertToast(alert: hostAlert) {
                        sessionRuntime.transfers.clearError()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }

                if let session = sessionRuntime.session,
                   session.sessionType.lowercased() == "ssh",
                   surfaceView.childExitedMessage != nil,
                   isFocusedSurface {
                    SSHReconnectOverlay(
                        state: sessionRuntime.reconnect.state,
                        onReconnect: { reconnect(session: session) },
                        onPause: { sessionRuntime.reconnect.pause() },
                        onResume: {
                            if let delay = sessionRuntime.reconnect.resume() {
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(delay))
                                    guard case .waiting = sessionRuntime.reconnect.state else { return }
                                    guard let command = try? session.buildProcessSpec().shellCommand else { return }
                                    var config = SpectrePro.SurfaceConfiguration()
                                    config.command = command
                                    NotificationCenter.default.post(
                                        name: SpectrePro.Notification.spectreproReplaceSurface,
                                        object: surfaceView,
                                        userInfo: [SpectrePro.Notification.NewSurfaceConfigKey: config]
                                    )
                                }
                            }
                        },
                        onCancel: { sessionRuntime.reconnect.cancel() }
                    )
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: serialWatcher.activeAlert)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: processMonitor.activePortAlert)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: processMonitor.activeCommandAlert)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: copiedHudMessage)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sessionRuntime.transfers.lastHostKeyAlert != nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
        }

        private func reconnect(session: SavedSession) {
            let reason = surfaceView.childExitedMessage?.text ?? "SSH process exited"
            guard let delay = sessionRuntime.reconnect.disconnected(reason: reason) else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                guard case .waiting = sessionRuntime.reconnect.state else { return }
                guard let command = try? session.buildProcessSpec().shellCommand else { return }
                var config = SpectrePro.SurfaceConfiguration()
                config.command = command
                NotificationCenter.default.post(
                    name: SpectrePro.Notification.spectreproReplaceSurface,
                    object: surfaceView,
                    userInfo: [SpectrePro.Notification.NewSurfaceConfigKey: config]
                )
            }
        }
    }

    private struct HostKeyAlertToast: View {
        let alert: HostKeyAlert
        let onDismiss: () -> Void

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.host)
                        .font(.system(size: 11, weight: .bold))
                    Text(alert.message)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if let offending = alert.offendingLine {
                        Text(offending)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor).opacity(0.95)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
    }

    private struct SSHReconnectOverlay: View {
        let state: SSHReconnectState
        let onReconnect: () -> Void
        let onPause: () -> Void
        let onResume: () -> Void
        let onCancel: () -> Void

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: isOffline ? "wifi.slash" : "network.slash")
                    .foregroundStyle(isOffline ? .red : .orange)
                Text(message)
                    .font(.system(size: 11, weight: .medium))

                if case .waiting = state {
                    Button("Pause", action: onPause)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if case .paused = state {
                    Button("Resume", action: onResume)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Button("Reconnect", action: onReconnect)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isWaiting || isOffline)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color(nsColor: .windowBackgroundColor).opacity(0.95)))
            .overlay(Capsule().stroke(isOffline ? Color.red.opacity(0.45) : Color.orange.opacity(0.45), lineWidth: 1))
        }

        private var isOffline: Bool {
            if case .networkUnavailable = state { return true }
            return false
        }

        private var isWaiting: Bool {
            if case .waiting = state { return true }
            return false
        }

        private var message: String {
            switch state {
            case .waiting(let attempt, let delay):
                return "Connection lost. Retry \(attempt) in \(Int(delay))s"
            case .paused(let attempt):
                return "Reconnection paused (attempt \(attempt))"
            case .cancelled:
                return "Reconnection cancelled"
            case .networkUnavailable:
                return "Network offline. Waiting for connection..."
            case .exhausted:
                return "Reconnect attempts exhausted"
            default:
                return "Connection lost"
            }
        }
    }

    struct SurfaceRendererUnhealthyView: View {
        var body: some View {
            HStack {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)

                VStack(alignment: .leading) {
                    Text("Oh, no. 😭").font(.title)
                    Text("""
                        The renderer has failed. This is usually due to exhausting
                        available GPU memory. Please free up available resources.
                        """.replacingOccurrences(of: "\n", with: " ")
                    )
                    .frame(maxWidth: 350)
                }
            }
            .padding()
        }
    }

    struct SurfaceErrorView: View {
        var body: some View {
            HStack {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)

                VStack(alignment: .leading) {
                    Text("Oh, no. 😭").font(.title)
                    Text("""
                        The terminal failed to initialize. Please check the logs for
                        more information. This is usually a bug.
                        """.replacingOccurrences(of: "\n", with: " ")
                    )
                    .frame(maxWidth: 350)
                }
            }
            .padding()
        }
    }

    // This is the resize overlay that shows on top of a surface to show the current
    // size during a resize operation.
    struct SurfaceResizeOverlay: View {
        let geoSize: CGSize
        let size: spectrepro_surface_size_s
        let overlay: SpectrePro.Config.ResizeOverlay
        let position: SpectrePro.Config.ResizeOverlayPosition
        let duration: UInt
        let focusInstant: ContinuousClock.Instant?

        // This is the last size that we processed. This is how we handle our
        // timer state.
        @State var lastSize: CGSize?

        // Ready is set to true after a short delay. This avoids some of the
        // challenges of initial view sizing from SwiftUI.
        @State var ready: Bool = false

        // Fixed value set based on personal taste.
        private let padding: CGFloat = 5

        // This computed boolean is set to true when the overlay should be hidden.
        private var hidden: Bool {
            // If we aren't ready yet then we wait...
            if !ready { return true; }

            // Hidden if we already processed this size.
            if lastSize == geoSize { return true; }

            // If we were focused recently we hide it as well. This avoids showing
            // the resize overlay when SwiftUI is lazily resizing.
            if let instant = focusInstant {
                let d = instant.duration(to: ContinuousClock.now)
                if d < .milliseconds(500) {
                    // Avoid this size completely. We can't set values during
                    // view updates so we have to defer this to another tick.
                    DispatchQueue.main.async {
                        lastSize = geoSize
                    }

                    return true
                }
            }

            // Hidden depending on overlay config
            switch overlay {
            case .never: return true
            case .always: return false
            case .after_first: return lastSize == nil
            }
        }

        var body: some View {
            VStack {
                if !position.top() {
                    Spacer()
                }

                HStack {
                    if !position.left() {
                        Spacer()
                    }

                    Text(verbatim: "\(size.columns) ⨯ \(size.rows)")
                        .padding(.init(top: padding, leading: padding, bottom: padding, trailing: padding))
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.background)
                                .shadow(radius: 3)
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !position.right() {
                        Spacer()
                    }
                }

                if !position.bottom() {
                    Spacer()
                }
            }
            .allowsHitTesting(false)
            .opacity(hidden ? 0 : 1)
            .task {
                // Sleep chosen arbitrarily... a better long term solution would be to detect
                // when the size stabilizes (coalesce a value) for the first time and then after
                // that show the resize overlay consistently.
                try? await Task.sleep(nanoseconds: 500 * 1_000_000)
                ready = true
            }
            .task(id: geoSize) {
                // By ID-ing the task on the geoSize, we get the task to restart if our
                // geoSize changes. This also ensures that future resize overlays are shown
                // properly.

                // We only sleep if we're ready. If we're not ready then we want to set
                // our last size right away to avoid a flash.
                if ready {
                    try? await Task.sleep(nanoseconds: UInt64(duration) * 1_000_000)
                }

                lastSize = geoSize
            }
        }
    }

    /// Search overlay view that displays a search bar with input field and navigation buttons.
    struct SurfaceSearchOverlay: View {
        let surfaceView: SurfaceView
        @ObservedObject var searchState: SurfaceView.SearchState
        let onClose: () -> Void
        @State private var corner: Corner = .topRight
        @State private var dragOffset: CGSize = .zero
        @State private var barSize: CGSize = .zero
        @FocusState private var isSearchFieldFocused: Bool

        private let padding: CGFloat = 8

        var body: some View {
            GeometryReader { geo in
                HStack(spacing: 4) {
                    BackportSelectionTextField(
                        "Search",
                        text: $searchState.needle.text,
                        selection: $searchState.needle.selection
                    )
                    .textFieldStyle(.plain)
                    .frame(width: 180)
                    .padding(.leading, 8)
                    .padding(.trailing, 50)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(6)
                    .focused($isSearchFieldFocused)
                    .overlay(alignment: .trailing) {
                        if let selected = searchState.selected {
                            Text("\(selected + 1)/\(searchState.total, default: "?")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                                .padding(.trailing, 8)
                        } else if let total = searchState.total {
                            Text("-/\(total)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                                .padding(.trailing, 8)
                        }
                    }
                    .onChange(of: searchState.needle.text) { _ in
                        searchState.writePasteboardNeedle()
                    }
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: NSApplication.didBecomeActiveNotification
                        )
                    ) { _ in
                        // When the app becomes active, we want to check for external changes
                        // to our synced needle.
                        searchState.readPasteboardNeedle()
                    }
                    .onSubmit {
                        _ = surfaceView.navigateSearchToNext()
                    }
                    .onExitCommand {
                        if searchState.needle.text.isEmpty {
                            onClose()
                        } else {
                            SpectrePro.moveFocus(to: surfaceView)
                        }
                    }
                    .backport.onKeyPress(.return) { modifiers in
                        if modifiers.contains(.shift) {
                            _ = surfaceView.navigateSearchToPrevious()
                            return .handled
                        }
                        return .ignored
                    }

                    Button(action: {
                        _ = surfaceView.navigateSearchToNext()
                    }, label: {
                        Image(systemName: "chevron.up")
                    })
                    .buttonStyle(SearchButtonStyle())

                    Button(action: {
                        guard let surface = surfaceView.surface else { return }
                        let action = "navigate_search:previous"
                        spectrepro_surface_binding_action(surface, action, UInt(action.lengthOfBytes(using: .utf8)))
                    }, label: {
                        Image(systemName: "chevron.down")
                    })
                    .buttonStyle(SearchButtonStyle())

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(SearchButtonStyle())
                }
                .padding(8)
                .background(.background)
                .clipShape(clipShape)
                .shadow(radius: 4)
                .onAppear {
                    isSearchFieldFocused = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .spectreproSearchFocus)) { notification in
                    guard notification.object as? SurfaceView === surfaceView else { return }
                    DispatchQueue.main.async {
                        isSearchFieldFocused = true
                    }
                }
                .background(
                    GeometryReader { barGeo in
                        Color.clear.onAppear {
                            barSize = barGeo.size
                        }
                    }
                )
                .padding(padding)
                .offset(dragOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner.alignment)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            let centerPos = centerPosition(for: corner, in: geo.size, barSize: barSize)
                            let newCenter = CGPoint(
                                x: centerPos.x + value.translation.width,
                                y: centerPos.y + value.translation.height
                            )
                            let newCorner = closestCorner(to: newCenter, in: geo.size)
                            withAnimation(.easeOut(duration: 0.2)) {
                                corner = newCorner
                                dragOffset = .zero
                            }
                        }
                )
            }
        }

        private var clipShape: some Shape {
            if #available(macOS 26.0, *) {
                return ConcentricRectangle(corners: .concentric(minimum: 8), isUniform: true)
            } else {
                return RoundedRectangle(cornerRadius: 8)
            }
        }

        enum Corner {
            case topLeft, topRight, bottomLeft, bottomRight

            var alignment: Alignment {
                switch self {
                case .topLeft: return .topLeading
                case .topRight: return .topTrailing
                case .bottomLeft: return .bottomLeading
                case .bottomRight: return .bottomTrailing
                }
            }
        }

        private func centerPosition(for corner: Corner, in containerSize: CGSize, barSize: CGSize) -> CGPoint {
            let halfWidth = barSize.width / 2 + padding
            let halfHeight = barSize.height / 2 + padding

            switch corner {
            case .topLeft:
                return CGPoint(x: halfWidth, y: halfHeight)
            case .topRight:
                return CGPoint(x: containerSize.width - halfWidth, y: halfHeight)
            case .bottomLeft:
                return CGPoint(x: halfWidth, y: containerSize.height - halfHeight)
            case .bottomRight:
                return CGPoint(x: containerSize.width - halfWidth, y: containerSize.height - halfHeight)
            }
        }

        private func closestCorner(to point: CGPoint, in containerSize: CGSize) -> Corner {
            let midX = containerSize.width / 2
            let midY = containerSize.height / 2

            if point.x < midX {
                return point.y < midY ? .topLeft : .bottomLeft
            } else {
                return point.y < midY ? .topRight : .bottomRight
            }
        }

        struct SearchButtonStyle: ButtonStyle {
            @State private var isHovered = false

            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .foregroundStyle(isHovered || configuration.isPressed ? .primary : .secondary)
                    .padding(.horizontal, 2)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(backgroundColor(isPressed: configuration.isPressed))
                    )
                    .onHover { hovering in
                        isHovered = hovering
                    }
                    .backport.pointerStyle(.link)
            }

            private func backgroundColor(isPressed: Bool) -> Color {
                if isPressed {
                    return Color.primary.opacity(0.2)
                } else if isHovered {
                    return Color.primary.opacity(0.1)
                } else {
                    return Color.clear
                }
            }
        }
    }

    /// A surface is terminology in SpectrePro for a terminal surface, or a place where a terminal is actually drawn
    /// and interacted with. The word "surface" is used because a surface may represent a window, a tab,
    /// a split, a small preview pane, etc. It is ANYTHING that has a terminal drawn to it.
    struct SurfaceRepresentable: NSViewRepresentable {
        /// The view to render for the terminal surface.
        let view: SurfaceView

        /// The size of the frame containing this view. We use this to update the the underlying
        /// surface. This does not actually SET the size of our frame, this only sets the size
        /// of our Metal surface for drawing.
        ///
        /// Note: we do NOT use the NSView.resize function because SwiftUI on macOS 12
        /// does not call this callback (macOS 13+ does).
        ///
        /// The best approach is to wrap this view in a GeometryReader and pass in the geo.size.
        let size: CGSize

        func makeNSView(context: Context) -> SurfaceScrollView {
            return SurfaceScrollView(contentSize: size, surfaceView: view)
        }

        func updateNSView(_ scrollView: SurfaceScrollView, context: Context) {
            // SwiftUI may defer frame updates under system load (e.g., memory
            // pressure, heavy I/O) or when external window managers trigger rapid
            // layout changes. When that happens, the scroll view's bounds can
            // fall out of sync with the size reported by GeometryReader, causing
            // the surface to render at stale dimensions.
            guard scrollView.bounds.size != size else { return }
            scrollView.needsLayout = true
        }
    }

    /// The configuration for a surface. For any configuration not set, defaults will be chosen from
    /// libspectrepro, usually from the SpectrePro configuration.
    struct SurfaceConfiguration {
        /// Explicit font size to use in points
        var fontSize: Float32?

        /// Explicit working directory. This is normalized on assignment to
        /// remove any redundant and trailing path separators.
        var workingDirectory: String? {
            get { normalizedWorkingDirectory }
            set { normalizedWorkingDirectory = newValue.map { FilePath($0).string } }
        }
        private var normalizedWorkingDirectory: String?

        /// Explicit command to set
        var command: String?

        /// Environment variables to set for the terminal
        var environmentVariables: [String: String] = [:]

        /// Extra input to send as stdin
        var initialInput: String?

        /// Wait after the command
        var waitAfterCommand: Bool = false

        /// Context for surface creation
        var context: spectrepro_surface_context_e = SPECTREPRO_SURFACE_CONTEXT_WINDOW

        /// Native serial backend options. A nil device keeps the normal PTY backend.
        var serialDevice: String?
        var serialBaudRate: UInt32 = 115200
        var serialDataBits: UInt8 = 8
        var serialParity: UInt8 = 0
        var serialStopBits: UInt8 = 1
        var serialFlowControl: UInt8 = 0

        init() {}

        init(serial config: SerialConnectionConfig) {
            self.init()
            self.serialDevice = config.devicePath
            self.serialBaudRate = UInt32(config.baudRate)
            self.serialDataBits = UInt8(config.dataBits)
            self.serialParity = switch config.parity {
            case "Odd": 1
            case "Even": 2
            default: 0
            }
            self.serialStopBits = UInt8(config.stopBits == 2 ? 2 : 1)
            self.serialFlowControl = switch config.flowControl {
            case "Hardware": 1
            case "Software": 2
            default: 0
            }
        }

        init(from config: spectrepro_surface_config_s) {
            self.fontSize = config.font_size
            if let workingDirectory = config.working_directory {
                self.workingDirectory = String.init(cString: workingDirectory, encoding: .utf8)
            }
            if let command = config.command {
                self.command = String.init(cString: command, encoding: .utf8)
            }

            // Convert the C env vars to Swift dictionary
            if config.env_var_count > 0, let envVars = config.env_vars {
                for i in 0..<config.env_var_count {
                    let envVar = envVars[i]
                    if let key = String(cString: envVar.key, encoding: .utf8),
                       let value = String(cString: envVar.value, encoding: .utf8) {
                        self.environmentVariables[key] = value
                    }
                }
            }
            self.context = config.context
            if let serialDevice = config.serial_device {
                self.serialDevice = String(cString: serialDevice)
            }
            self.serialBaudRate = config.serial_baud_rate
            self.serialDataBits = config.serial_data_bits
            self.serialParity = config.serial_parity
            self.serialStopBits = config.serial_stop_bits
            self.serialFlowControl = config.serial_flow_control
        }

        /// Provides a C-compatible spectrepro configuration within a closure. The configuration
        /// and all its string pointers are only valid within the closure.
        func withCValue<T>(view: SurfaceView, _ body: (inout spectrepro_surface_config_s) throws -> T) rethrows -> T {
            var config = spectrepro_surface_config_new()
            config.userdata = Unmanaged.passUnretained(view).toOpaque()
            config.platform_tag = SPECTREPRO_PLATFORM_MACOS
            config.platform = spectrepro_platform_u(macos: spectrepro_platform_macos_s(
                nsview: Unmanaged.passUnretained(view).toOpaque()
            ))
            config.scale_factor = Double((view.window?.screen ?? NSScreen.main)?.backingScaleFactor ?? 1.0)

            // Zero is our default value that means to inherit the font size.
            config.font_size = fontSize ?? 0

            // Set wait after command
            config.wait_after_command = waitAfterCommand

            // Set context
            config.context = context
            config.serial_baud_rate = serialBaudRate
            config.serial_data_bits = serialDataBits
            config.serial_parity = serialParity
            config.serial_stop_bits = serialStopBits
            config.serial_flow_control = serialFlowControl

            // Use withCString to ensure strings remain valid for the duration of the closure
            return try workingDirectory.withCString { cWorkingDir in
                config.working_directory = cWorkingDir

                return try command.withCString { cCommand in
                    config.command = cCommand

                    return try serialDevice.withCString { cSerialDevice in
                        config.serial_device = cSerialDevice

                    return try initialInput.withCString { cInput in
                        config.initial_input = cInput

                        // Convert dictionary to arrays for easier processing
                        let keys = Array(environmentVariables.keys)
                        let values = Array(environmentVariables.values)

                        // Create C strings for all keys and values
                        return try keys.withCStrings { keyCStrings in
                            return try values.withCStrings { valueCStrings in
                                // Create array of spectrepro_env_var_s
                                var envVars = [spectrepro_env_var_s]()
                                envVars.reserveCapacity(environmentVariables.count)
                                for i in 0..<environmentVariables.count {
                                    envVars.append(spectrepro_env_var_s(
                                        key: keyCStrings[i],
                                        value: valueCStrings[i]
                                    ))
                                }

                                return try envVars.withUnsafeMutableBufferPointer { buffer in
                                    config.env_vars = buffer.baseAddress
                                    config.env_var_count = environmentVariables.count
                                    return try body(&config)
                                }
                            }
                        }
                    }
                    }
                }
            }
        }
    }

    /// Floating indicator that shows active key tables and pending key sequences.
    /// Displayed as a compact draggable pill that can be positioned at the top or bottom.
    struct KeyStateIndicator: View {
        let keyTables: [String]
        let keySequence: [KeyboardShortcut]

        @State private var isShowingPopover = false
        @State private var position: Position = .bottom
        @State private var dragOffset: CGSize = .zero
        @State private var isDragging = false

        private let padding: CGFloat = 8

        enum Position {
            case top, bottom

            var alignment: Alignment {
                switch self {
                case .top: return .top
                case .bottom: return .bottom
                }
            }

            var popoverEdge: Edge {
                switch self {
                case .top: return .top
                case .bottom: return .bottom
                }
            }

            var transitionEdge: Edge {
                popoverEdge
            }
        }

        var body: some View {
            Group {
                if !keyTables.isEmpty || !keySequence.isEmpty {
                    content
                        .backport.pointerStyle(!keyTables.isEmpty ? .link : nil)
                }
            }
            .transition(.move(edge: position.transitionEdge).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: keyTables)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: keySequence.count)
        }

        var content: some View {
            indicatorContent
                .offset(dragOffset)
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
                .highPriorityGesture(
                    DragGesture(coordinateSpace: .local)
                        .onChanged { value in
                            isDragging = true
                            dragOffset = CGSize(width: 0, height: value.translation.height)
                        }
                        .onEnded { value in
                            isDragging = false
                            let dragThreshold: CGFloat = 50

                            withAnimation(.easeOut(duration: 0.2)) {
                                if position == .bottom && value.translation.height < -dragThreshold {
                                    position = .top
                                } else if position == .top && value.translation.height > dragThreshold {
                                    position = .bottom
                                }
                                dragOffset = .zero
                            }
                        }
                )
        }

        @ViewBuilder
        private var indicatorContent: some View {
            HStack(alignment: .center, spacing: 8) {
                // Key table indicator
                if !keyTables.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "keyboard.badge.ellipsis")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        // Show table stack with arrows between them
                        ForEach(Array(keyTables.enumerated()), id: \.offset) { index, table in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            Text(verbatim: table)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                    }
                }

                // Separator when both are active
                if !keyTables.isEmpty && !keySequence.isEmpty {
                    Divider()
                        .frame(height: 14)
                }

                // Key sequence indicator
                if !keySequence.isEmpty {
                    HStack(alignment: .center, spacing: 4) {
                        ForEach(Array(keySequence.enumerated()), id: \.offset) { _, key in
                            KeyCap(key.description)
                        }

                        // Animated ellipsis to indicate waiting for next key
                        PendingIndicator(paused: isDragging)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(.regularMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
            }
            .contentShape(Capsule())
            .backport.pointerStyle(.link)
            .popover(isPresented: $isShowingPopover, arrowEdge: position.popoverEdge) {
                VStack(alignment: .leading, spacing: 8) {
                    if !keyTables.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Key Table", systemImage: "keyboard.badge.ellipsis")
                                .font(.headline)
                            Text("A key table is a named set of keybindings, activated by some other key. Keys are interpreted using this table until it is deactivated.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !keyTables.isEmpty && !keySequence.isEmpty {
                        Divider()
                    }

                    if !keySequence.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Key Sequence", systemImage: "character.cursor.ibeam")
                                .font(.headline)
                            Text("A key sequence is a series of key presses that trigger an action. A pending key sequence is currently active.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 400)
                .fixedSize(horizontal: false, vertical: true)
            }
            .onTapGesture {
                isShowingPopover.toggle()
            }
        }

        /// A small keycap-style view for displaying keyboard shortcuts
        struct KeyCap: View {
            let text: String

            init(_ text: String) {
                self.text = text
            }

            var body: some View {
                Text(verbatim: text)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                    )
            }
        }

        /// Animated dots to indicate waiting for the next key
        struct PendingIndicator: View {
            @State private var animationPhase: Double = 0
            let paused: Bool

            var body: some View {
                TimelineView(.animation(paused: paused)) { context in
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 4, height: 4)
                                .opacity(dotOpacity(for: index))
                        }
                    }
                    .onChange(of: context.date.timeIntervalSinceReferenceDate) { newValue in
                        animationPhase = newValue
                    }
                }
            }

            private func dotOpacity(for index: Int) -> Double {
                let phase = animationPhase
                let offset = Double(index) / 3.0
                let wave = sin((phase + offset) * .pi * 2)
                return 0.3 + 0.7 * ((wave + 1) / 2)
            }
        }
    }

    /// Visual overlay that shows a border around the edges when the bell rings with border feature enabled.
    struct BellBorderOverlay: View {
        let bell: Bool

        var body: some View {
            Rectangle()
                .strokeBorder(
                    Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.5),
                    lineWidth: 3
                )
                .allowsHitTesting(false)
                .opacity(bell ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: bell)
        }
    }

    /// Visual overlay that briefly highlights a surface to draw attention to it.
    /// Uses a soft, soothing highlight with a pulsing border effect.
    struct HighlightOverlay: View {
        let highlighted: Bool

        @State private var borderPulse: Bool = false

        var body: some View {
            ZStack {
                Rectangle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.12),
                                Color.accentColor.opacity(0.03),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 2000
                        )
                    )

                Rectangle()
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.8),
                                Color.accentColor.opacity(0.5),
                                Color.accentColor.opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderPulse ? 4 : 2
                    )
                    .shadow(color: Color.accentColor.opacity(borderPulse ? 0.8 : 0.6), radius: borderPulse ? 12 : 8, x: 0, y: 0)
                    .shadow(color: Color.accentColor.opacity(borderPulse ? 0.5 : 0.3), radius: borderPulse ? 24 : 16, x: 0, y: 0)
            }
            .allowsHitTesting(false)
            .opacity(highlighted ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4), value: highlighted)
            .onChange(of: highlighted) { newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                        borderPulse = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.4)) {
                        borderPulse = false
                    }
                }
            }
        }
    }

    // MARK: Readonly Badge

    /// A badge overlay that indicates a surface is in readonly mode.
    /// Positioned in the top-right corner and styled to be noticeable but unobtrusive.
    struct ReadonlyBadge: View {
        let onDisable: () -> Void

        @State private var showingPopover = false

        private let badgeColor = Color(hue: 0.08, saturation: 0.5, brightness: 0.8)

        var body: some View {
            VStack {
                HStack {
                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12))
                        Text("Read-only")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeBackground)
                    .foregroundStyle(badgeColor)
                    .onTapGesture {
                        showingPopover = true
                    }
                    .backport.pointerStyle(.link)
                    .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
                        ReadonlyPopoverView(onDisable: onDisable, isPresented: $showingPopover)
                    }
                }
                .padding(8)

                Spacer()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Read-only terminal")
        }

        private var badgeBackground: some View {
            RoundedRectangle(cornerRadius: 6)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.orange.opacity(0.6), lineWidth: 1.5)
                )
        }
    }

    struct ReadonlyPopoverView: View {
        let onDisable: () -> Void
        @Binding var isPresented: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                        Text("Read-Only Mode")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    Text("This terminal is in read-only mode. You can still view, select, and scroll through the content, but no input events will be sent to the running application.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()

                    Button("Disable") {
                        onDisable()
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(16)
            .frame(width: 280)
        }
    }

    /// When changing the split state, or going full screen (native or non), the terminal view
    /// will lose focus. There has to be some nice SwiftUI-native way to fix this but I can't
    /// figure it out so we're going to do this hacky thing to bring focus back to the terminal
    /// that should have it.
    static func moveFocus(
        to: SurfaceView,
        from: SurfaceView? = nil,
        delay: TimeInterval? = nil
    ) {
        // The whole delay machinery is a bit of a hack to work around a
        // situation where the window is destroyed and the surface view
        // will never be attached to a window. Realistically, we should
        // handle this upstream but we also don't want this function to be
        // a source of infinite loops.

        // Our max delay before we give up
        let maxDelay: TimeInterval = 0.5
        guard (delay ?? 0) < maxDelay else { return }

        // We start at a 50 millisecond delay and do a doubling backoff
        let nextDelay: TimeInterval = if let delay {
            delay * 2
        } else {
            // 100 milliseconds
            0.05
        }

        let work: DispatchWorkItem = .init {
            // If the callback runs before the surface is attached to a view
            // then the window will be nil. We just reschedule in that case.
            guard let window = to.window else {
                moveFocus(to: to, from: from, delay: nextDelay)
                return
            }

            // If we had a previously focused node and its not where we're sending
            // focus, make sure that we explicitly tell it to lose focus. In theory
            // we should NOT have to do this but the focus callback isn't getting
            // called for some reason.
            if let from = from {
                _ = from.resignFirstResponder()
            }

            window.makeFirstResponder(to)
        }

        let queue = DispatchQueue.main
        if let delay {
            queue.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            queue.async(execute: work)
        }
    }
}

// MARK: Surface Environment Keys

private struct SpectreProSurfaceViewKey: EnvironmentKey {
    static let defaultValue: SpectrePro.SurfaceView? = nil
}

private struct SpectreProLastFocusedSurfaceKey: EnvironmentKey {
    /// Optional read-only last-focused surface reference. If a surface view is currently focused this
    /// is equal to the currently focused surface.
    static let defaultValue: Weak<SpectrePro.SurfaceView>? = nil
}

extension EnvironmentValues {
    var spectreproSurfaceView: SpectrePro.SurfaceView? {
        get { self[SpectreProSurfaceViewKey.self] }
        set { self[SpectreProSurfaceViewKey.self] = newValue }
    }

    var spectreproLastFocusedSurface: Weak<SpectrePro.SurfaceView>? {
        get { self[SpectreProLastFocusedSurfaceKey.self] }
        set { self[SpectreProLastFocusedSurfaceKey.self] = newValue }
    }
}

extension View {
    func spectreproSurfaceView(_ surfaceView: SpectrePro.SurfaceView?) -> some View {
        environment(\.spectreproSurfaceView, surfaceView)
    }

    /// The most recently focused surface (can be currently focused if the surface is currently focused).
    func spectreproLastFocusedSurface(_ surfaceView: Weak<SpectrePro.SurfaceView>?) -> some View {
        environment(\.spectreproLastFocusedSurface, surfaceView)
    }
}

// MARK: Surface Focus Keys

extension FocusedValues {
    var spectreproSurfaceView: SpectrePro.SurfaceView? {
        get { self[FocusedSpectreProSurface.self] }
        set { self[FocusedSpectreProSurface.self] = newValue }
    }

    struct FocusedSpectreProSurface: FocusedValueKey {
        typealias Value = SpectrePro.SurfaceView
    }

    var spectreproSurfacePwd: String? {
        get { self[FocusedSpectreProSurfacePwd.self] }
        set { self[FocusedSpectreProSurfacePwd.self] = newValue }
    }

    struct FocusedSpectreProSurfacePwd: FocusedValueKey {
        typealias Value = String
    }

    var spectreproSurfaceCellSize: CGSize? {
        get { self[FocusedSpectreProSurfaceCellSize.self] }
        set { self[FocusedSpectreProSurfaceCellSize.self] = newValue }
    }

    struct FocusedSpectreProSurfaceCellSize: FocusedValueKey {
        typealias Value = CGSize
    }
}

extension Notification.Name {
    static let spectreproCopiedOutput = Notification.Name("SpectreProCopiedOutputNotification")
    static let spectreproOpenSFTPBrowser = Notification.Name("co.skyones.spectrepro.openSFTPBrowser")
}
