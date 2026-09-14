import SwiftUI
import AppKit
import Darwin

public struct SerialConnectionConfig: Equatable {
    public var name: String
    public var devicePath: String
    public var baudRate: Int
    public var dataBits: Int
    public var parity: String
    public var stopBits: Double
    public var flowControl: String
    public var closeOnExit: Bool
    public var deleteSendsCtrlH: Bool
    public var vt100Keypad: Bool

    // SecureCRT Hardware Tools: Line and Character delay
    public var lineDelayMs: Int
    public var charDelayMs: Int

    public static func `default`(for path: String, name: String? = nil) -> SerialConnectionConfig {
        let cleanName = name ?? (path as NSString).lastPathComponent.replacingOccurrences(of: "cu.", with: "")
        return SerialConnectionConfig(
            name: cleanName,
            devicePath: path,
            baudRate: 115200,
            dataBits: 8,
            parity: "None",
            stopBits: 1.0,
            flowControl: "None",
            closeOnExit: false,
            deleteSendsCtrlH: false,
            vt100Keypad: true,
            lineDelayMs: 0,
            charDelayMs: 0
        )
    }

    public func buildLaunchCommand() -> String {
        "screen \(devicePath) \(baudRate)"
    }

}

enum SerialInspectorSelection {
    static func requiresConfigurationReset(previousPath: String?, newPath: String) -> Bool {
        previousPath != newPath
public enum SerialPasteEngine {
    public static func paste(
        _ text: String,
        lineDelayMs: Int,
        charDelayMs: Int,
        sendText: @escaping (String) async -> Void,
        sleep: @escaping (UInt64) async throws -> Void
    ) async throws {
        let lines = text.components(separatedBy: .newlines)
        let lineDelay = UInt64(max(lineDelayMs, 0)) * 1_000_000
        let charDelay = UInt64(max(charDelayMs, 0)) * 1_000_000

        for (lineIndex, line) in lines.enumerated() {
            for character in line {
                try Task.checkCancellation()
                await sendText(String(character))
                if charDelay > 0 {
                    try await sleep(charDelay)
                }
            }

            try Task.checkCancellation()
            await sendText("\n")
            if lineIndex < lines.count - 1, lineDelay > 0 {
                try await sleep(lineDelay)
            }
        }
    }
}

public struct SerialInspectorView: View {
    @ObservedObject var serialWatcher = SerialDeviceWatcher.shared
    @ObservedObject var state = QuickCommandsState.shared
    let surface: SpectrePro.SurfaceView?
    let onConnect: (SerialConnectionConfig, Bool) -> Void // (config, openInNewTab)
    var onSplitAndConnect: ((SerialConnectionConfig) -> Void)? = nil

    @State private var availablePorts: [SerialDevice] = []
    @State private var selectedDevice: SerialDevice? = nil
    @State private var config: SerialConnectionConfig = .default(for: "/dev/cu.usbserial", name: "Serial Port")

    // Hardware tools state
    @State private var breakFeedbackMessage: String? = nil
    @State private var isThrottledPasting = false
    @State private var pasteProgressMessage: String? = nil
    @State private var pasteTask: Task<Void, Never>?

    init(
        surface: SpectrePro.SurfaceView?,
        onConnect: @escaping (SerialConnectionConfig, Bool) -> Void,
        onSplitAndConnect: ((SerialConnectionConfig) -> Void)? = nil
    ) {
        self.surface = surface
        self.onConnect = onConnect
        self.onSplitAndConnect = onSplitAndConnect
    }

    private func refreshPorts() {
        var ports = SerialDeviceWatcher.allAvailablePorts()
        // Ensure connected devices from watcher are prioritized
        for d in serialWatcher.connectedDevices {
            if !ports.contains(where: { $0.bsdPath == d.bsdPath }) {
                ports.insert(d, at: 0)
            }
        }
        availablePorts = ports

        // Match selected device
        if let targetPath = state.selectedSerialDevicePath,
           let match = availablePorts.first(where: { $0.bsdPath == targetPath }) {
            selectDevice(match)
        } else if let selectedDevice,
                  !availablePorts.contains(where: { $0.bsdPath == selectedDevice.bsdPath }) {
            if let first = availablePorts.first {
                selectDevice(first)
            } else {
                self.selectedDevice = nil
                state.selectedSerialDevicePath = nil
            }
        } else if selectedDevice == nil, let first = availablePorts.first {
            selectDevice(first)
        }
    }

    private func selectDevice(_ dev: SerialDevice) {
        let shouldResetConfiguration = SerialInspectorSelection.requiresConfigurationReset(
            previousPath: selectedDevice?.bsdPath,
            newPath: dev.bsdPath
        )
        selectedDevice = dev
        state.selectedSerialDevicePath = dev.bsdPath
        if shouldResetConfiguration {
            config = .default(for: dev.bsdPath, name: dev.name)
        }
    }

    // MARK: - Hardware Break Signal

    private func triggerBreakSignal() {
        // The active surface owns the descriptor. Do not open a second fd:
        // that could assert BREAK on a different session than the one shown.
        guard let surfaceModel = surface?.surfaceModel else {
            breakFeedbackMessage = "Connect a serial session before sending Break"
            return
        }

        surfaceModel.sendSerialBreak(durationMilliseconds: 250)

        breakFeedbackMessage = "⚡ Break sent (250ms UART Break condition)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if breakFeedbackMessage?.hasPrefix("⚡ Break") == true {
                breakFeedbackMessage = nil
            }
        }
    }

    // MARK: - Throttled Paste (Line & Character Delay)

    private func performThrottledPaste() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string), !clipboardText.isEmpty else {
            pasteProgressMessage = "Clipboard is empty"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { pasteProgressMessage = nil }
            return
        }

        guard let surface = surface else {
            pasteProgressMessage = "No active terminal"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { pasteProgressMessage = nil }
            return
        }

        let totalLines = clipboardText.components(separatedBy: .newlines).count
        let lineDelay = max(config.lineDelayMs, 0)
        let charDelay = max(config.charDelayMs, 0)

        isThrottledPasting = true
        pasteProgressMessage = "Pasting 0/\(totalLines)..."

        pasteTask?.cancel()
        pasteTask = Task { @MainActor in
            do {
                var currentLine = 0
                try await SerialPasteEngine.paste(
                    clipboardText,
                    lineDelayMs: lineDelay,
                    charDelayMs: charDelay,
                    sendText: { text in
                        surface.surfaceModel?.sendText(text)
                        if text == "\n" {
                            currentLine += 1
                            pasteProgressMessage = "Pasting \(currentLine)/\(totalLines)..."
                        }
                    },
                    sleep: { nanoseconds in
                        try await Task.sleep(nanoseconds: nanoseconds)
                    }
                )
                isThrottledPasting = false
                pasteProgressMessage = "✓ \(totalLines) lines pasted"
                try await Task.sleep(nanoseconds: 2_000_000_000)
                pasteProgressMessage = nil
            } catch {
                isThrottledPasting = false
            }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Serial Connection")
                    .font(.headline)
                Spacer()
                Button {
                    refreshPorts()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Rescan Serial Ports")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Available Serial Ports Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DETECTED SERIAL PORTS (\(availablePorts.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)

                        if availablePorts.isEmpty {
                            Text("No serial devices detected. Plug in a USB-serial adapter.")
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.8))
                                .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 2) {
                                ForEach(availablePorts) { dev in
                                    let isSel = selectedDevice?.bsdPath == dev.bsdPath
                                    Button {
                                        selectDevice(dev)
                                    } label: {
                                        HStack(spacing: 6) {
                                        Image(systemName: dev.isUSB ? "cable.connector" : "cpu")
                                            .font(.system(size: 11))
                                            .foregroundStyle(isSel ? Color.accentColor : Color.secondary)
                                            .frame(width: 14)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(dev.name)
                                                .font(.system(size: 11, weight: isSel ? .semibold : .regular))
                                                .lineLimit(1)
                                            Text(dev.bsdPath)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        if isSel {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isSel ? Color.accentColor.opacity(0.12) : Color.clear)
                                    )
                                    .contentShape(Rectangle())
                                    .accessibilityLabel("\(dev.name), \(dev.bsdPath)")
                                    .accessibilityValue(isSel ? "Selected" : "Not selected")
                                    .accessibilityHint("Select this serial device")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)

                    Divider()

                    // Configuration Form
                    VStack(alignment: .leading, spacing: 12) {
                        // Descriptive Name
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Descriptive name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("e.g. wlan-debug or router-console", text: $config.name)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }

                        // Serial Port Parameters
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SERIAL PORT PARAMETERS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)

                            // Device Path
                            HStack {
                                Text("Device Path")
                                    .font(.system(size: 11))
                                Spacer()
                                Text(config.devicePath)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            // Baud Rate
                            HStack {
                                Text("Baud Rate")
                                    .font(.system(size: 11))
                                Spacer()
                                Picker("", selection: $config.baudRate) {
                                    ForEach(SerialDeviceWatcher.standardBaudRates, id: \.self) { rate in
                                        Text("\(rate)").tag(rate)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 110)
                            }

                            // Data Bits
                            HStack {
                                Text("Data Bits")
                                    .font(.system(size: 11))
                                Spacer()
                                Picker("", selection: $config.dataBits) {
                                    Text("8").tag(8)
                                    Text("7").tag(7)
                                    Text("6").tag(6)
                                    Text("5").tag(5)
                                }
                                .labelsHidden()
                                .frame(width: 110)
                            }

                            // Parity
                            HStack {
                                Text("Parity")
                                    .font(.system(size: 11))
                                Spacer()
                                Picker("", selection: $config.parity) {
                                    Text("None").tag("None")
                                    Text("Even").tag("Even")
                                    Text("Odd").tag("Odd")
                                }
                                .labelsHidden()
                                .frame(width: 110)
                            }

                            // Stop Bits
                            HStack {
                                Text("Stop Bits")
                                    .font(.system(size: 11))
                                Spacer()
                                Picker("", selection: $config.stopBits) {
                                    Text("1").tag(1.0)
                                    Text("2").tag(2.0)
                                }
                                .labelsHidden()
                                .frame(width: 110)
                            }

                            // Flow Control
                            HStack {
                                Text("Flow Control")
                                    .font(.system(size: 11))
                                Spacer()
                                Picker("", selection: $config.flowControl) {
                                    Text("None").tag("None")
                                    Text("Hardware (RTS/CTS)").tag("Hardware")
                                    Text("Software (XON/XOFF)").tag("Software")
                                }
                                .labelsHidden()
                                .frame(width: 110)
                            }
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)

                        // Hardware Tools Section (SecureCRT Grade)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("HARDWARE TOOLS & PASTE THROTTLING")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)

                            // Break Signal Button
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Send Break Signal")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("Triggers Cisco ROMMON / U-Boot bootloader.")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    triggerBreakSignal()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 10))
                                        Text("Send Break")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.orange.opacity(0.9))
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            if let msg = breakFeedbackMessage {
                                Text(msg)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.orange)
                                    .padding(.vertical, 2)
                            }

                            Divider()

                            // Paste Throttling
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Line Delay (Slow UARTs)")
                                        .font(.system(size: 11))
                                    Spacer()
                                    Picker("", selection: $config.lineDelayMs) {
                                        Text("None (0ms)").tag(0)
                                        Text("20 ms").tag(20)
                                        Text("50 ms").tag(50)
                                        Text("100 ms").tag(100)
                                        Text("250 ms").tag(250)
                                    }
                                    .labelsHidden()
                                    .frame(width: 120)
                                }

                                HStack {
                                    Text("Character Delay")
                                        .font(.system(size: 11))
                                    Spacer()
                                    Picker("", selection: $config.charDelayMs) {
                                        Text("None (0ms)").tag(0)
                                        Text("1 ms").tag(1)
                                        Text("2 ms").tag(2)
                                        Text("5 ms").tag(5)
                                        Text("10 ms").tag(10)
                                    }
                                    .labelsHidden()
                                    .frame(width: 120)
                                    .focusable(false)
                                }

                                Text("Character delay applies between characters; line delay applies between lines.")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)

                                HStack {
                                    Button {
                                        performThrottledPaste()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc.on.clipboard")
                                                .font(.system(size: 10))
                                            Text(isThrottledPasting ? "Pasting..." : "Paste Throttled")
                                                .font(.system(size: 10))
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(isThrottledPasting)

                                    if let progress = pasteProgressMessage {
                                        Text(progress)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)

                        // Terminal Settings
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TERMINAL OPTIONS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)

                            HStack {
                                Text("When shell exits")
                                    .font(.system(size: 11))
                                Spacer()
                                Picker("", selection: $config.closeOnExit) {
                                    Text("Don't close terminal").tag(false)
                                    Text("Close terminal").tag(true)
                                }
                                .labelsHidden()
                                .frame(width: 140)
                            }

                            Toggle("Delete sends Control-H", isOn: $config.deleteSendsCtrlH)
                                .font(.system(size: 11))

                            Toggle("Allow VT100 application keypad mode", isOn: $config.vt100Keypad)
                                .font(.system(size: 11))
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Bottom Action Buttons
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button("Restore Defaults") {
                        if let sel = selectedDevice {
                            config = .default(for: sel.bsdPath, name: sel.name)
                        }
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    // Connect in Current Tab
                    Button("Connect Here") {
                        onConnect(config, false)
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    // Open in Split
                    if let onSplitAndConnect = onSplitAndConnect {
                        Button("Open in Split") {
                            onSplitAndConnect(config)
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Spacer()

                    // Open in New Tab
                    Button {
                        onConnect(config, true)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.rectangle")
                                .font(.system(size: 11))
                            Text("Open in New Tab")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            refreshPorts()
        }
        .onDisappear {
            pasteTask?.cancel()
            pasteTask = nil
            isThrottledPasting = false
            pasteProgressMessage = nil
        }
        .onChange(of: serialWatcher.connectedDevices) { _ in
            refreshPorts()
        }
        .onChange(of: state.selectedSerialDevicePath) { newPath in
            if let newPath, let match = availablePorts.first(where: { $0.bsdPath == newPath }) {
                selectDevice(match)
            }
        }
    }
}
