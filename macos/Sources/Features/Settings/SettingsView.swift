import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @StateObject private var configuration = ConfigurationSettingsModel()

    var body: some View {
        TabView {
            Form {
                Section("Appearance") {
                    TextField("Theme", text: $configuration.theme, prompt: Text("e.g. Gruvbox Dark"))
                        .textFieldStyle(.roundedBorder)

                    Text("A theme takes precedence over custom terminal colors.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextField("Font Family", text: $configuration.fontFamily, prompt: Text("System default"))
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("Font Size")
                        Slider(value: $configuration.fontSize, in: 8...32, step: 0.5)
                        Text(configuration.fontSize, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }

                    Picker("Cursor", selection: $configuration.cursorStyle) {
                        Text("Block").tag("block")
                        Text("Bar").tag("bar")
                        Text("Underline").tag("underline")
                        Text("Hollow Block").tag("block_hollow")
                    }

                    TextField("Background Color", text: $configuration.backgroundColor, prompt: Text("#1E1E1E"))
                        .textFieldStyle(.roundedBorder)

                    TextField("Foreground Color", text: $configuration.foregroundColor, prompt: Text("#FFFFFF"))
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("Background Opacity")
                        Slider(value: $configuration.backgroundOpacity, in: 0.15...1, step: 0.05)
                        Text(configuration.backgroundOpacity, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }

                    Picker("Background Blur", selection: $configuration.backgroundBlur) {
                        Text("Off").tag("false")
                        Text("Standard").tag("true")
                        Text("Regular Glass").tag("macos-glass-regular")
                        Text("Clear Glass").tag("macos-glass-clear")
                    }
                }

                Section("Window Behavior") {
                    Picker("Restore Windows", selection: $configuration.windowSaveState) {
                        Text("System Default").tag("default")
                        Text("Always Restore").tag("always")
                        Text("Never Restore").tag("never")
                    }

                    Picker("New Window Fullscreen", selection: $configuration.fullscreenMode) {
                        Text("Windowed").tag("false")
                        Text("Native macOS").tag("true")
                        Text("Non-Native").tag("non-native")
                        Text("Non-Native with Menu Bar").tag("non-native-visible-menu")
                        Text("Non-Native with Notch Padding").tag("non-native-padded-notch")
                    }

                    Picker("Title Bar", selection: $configuration.titlebarStyle) {
                        Text("Native").tag("native")
                        Text("Transparent").tag("transparent")
                        Text("Tabs").tag("tabs")
                        Text("Hidden").tag("hidden")
                    }

                    Toggle("Show top bar", isOn: $configuration.showTopbar)

                    Toggle("Quit when the last window closes", isOn: $configuration.quitAfterLastWindowCloses)
                }

                Section("Terminal") {
                    TextField("Working Directory", text: $configuration.workingDirectory, prompt: Text("Home directory"))
                        .textFieldStyle(.roundedBorder)

                    Picker("Shell Integration", selection: $configuration.shellIntegration) {
                        Text("Automatic").tag("detect")
                        Text("Disabled").tag("none")
                    }

                    Picker("Copy on Select", selection: $configuration.copyOnSelect) {
                        Text("Disabled").tag("none")
                        Text("Clipboard").tag("clipboard")
                        Text("Primary Selection").tag("primary")
                    }

                    Toggle("Hide pointer while typing", isOn: $configuration.mouseHideWhileTyping)

                    TextField("Scrollback Limit", text: $configuration.scrollbackLimit, prompt: Text("50MB"))
                        .textFieldStyle(.roundedBorder)
                }

                Section("Privacy & Updates") {
                    Picker("Automatic Updates", selection: $configuration.autoUpdate) {
                        Text("Off").tag("off")
                        Text("Check and Notify").tag("check")
                        Text("Download and Notify").tag("download")
                    }

                    Picker("Update Channel", selection: $configuration.updateChannel) {
                        Text("Stable").tag("stable")
                        Text("Preview").tag("tip")
                    }

                    Picker("Option Key", selection: $configuration.optionAsAlt) {
                        Text("Follow Keyboard Layout").tag("")
                        Text("Use as Alt").tag("true")
                        Text("Use for Unicode Input").tag("false")
                        Text("Left Option as Alt").tag("left")
                        Text("Right Option as Alt").tag("right")
                    }

                    Toggle("Automatic Secure Input", isOn: $configuration.autoSecureInput)
                    Toggle("Show Secure Input Indicator", isOn: $configuration.secureInputIndication)
                }

                Section {
                    HStack {
                        Button("Apply Changes") {
                            configuration.apply(to: appDelegate.spectrepro)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!configuration.isLoaded)

                        if let status = configuration.statusMessage {
                            Text(status)
                                .foregroundStyle(configuration.didFail ? .red : .secondary)
                                .font(.footnote)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            .tabItem { Label("General", systemImage: "gearshape") }

            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)

                Text("Advanced Configuration")
                    .font(.title2.weight(.semibold))

                Text("Use the configuration file for key bindings, shell integration, themes with custom colors, and every advanced Spectre Pro option. Changes made here are preserved by General settings.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Open Configuration File") {
                        appDelegate.openConfig(nil)
                    }

                    Button("Open Terminal Studio") {
                        appDelegate.openConfigStudio(nil)
                    }
                }

                Spacer()
            }
            .padding(28)
            .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }

            ConfigurationReferenceView(configuration: configuration, app: appDelegate.spectrepro)
                .tabItem { Label("All Settings", systemImage: "list.bullet.rectangle") }
        }
        .task {
            configuration.load(from: appDelegate.spectrepro)
        }
        .frame(minWidth: 580, idealWidth: 640, minHeight: 430, idealHeight: 500)
    }
}

@MainActor
private final class ConfigurationSettingsModel: ObservableObject {
    @Published var theme = ""
    @Published var fontFamily = ""
    @Published var fontSize = 13.0
    @Published var cursorStyle = "block"
    @Published var backgroundColor = ""
    @Published var foregroundColor = ""
    @Published var backgroundOpacity = 1.0
    @Published var backgroundBlur = "false"
    @Published var windowSaveState = "default"
    @Published var fullscreenMode = "false"
    @Published var titlebarStyle = "transparent"
    @Published var showTopbar = false
    @Published var quitAfterLastWindowCloses = false
    @Published var workingDirectory = ""
    @Published var shellIntegration = "detect"
    @Published var copyOnSelect = "none"
    @Published var mouseHideWhileTyping = false
    @Published var scrollbackLimit = "50MB"
    @Published var autoUpdate = "check"
    @Published var updateChannel = "stable"
    @Published var optionAsAlt = ""
    @Published var autoSecureInput = true
    @Published var secureInputIndication = true
    @Published private(set) var isLoaded = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var didFail = false
    @Published private(set) var reference = [ConfigurationOption]()
    @Published private(set) var referenceStatus: ReferenceStatus = .idle
    @Published private var optionValues = [String: String]()

    func load(from app: SpectrePro.App) {
        let config = app.config
        theme = readValue(for: "theme", at: app.configurationFileURL) ?? ""
        fontFamily = readValue(for: "font-family", at: app.configurationFileURL) ?? ""
        fontSize = config.fontSize
        cursorStyle = config.cursorStyle
        backgroundColor = readValue(for: "background", at: app.configurationFileURL) ?? ""
        foregroundColor = readValue(for: "foreground", at: app.configurationFileURL) ?? ""
        backgroundOpacity = doubleValue(for: "background-opacity", at: app.configurationFileURL, default: 1)
        backgroundBlur = readValue(for: "background-blur", at: app.configurationFileURL) ?? "false"
        windowSaveState = config.windowSaveState
        fullscreenMode = readValue(for: "fullscreen", at: app.configurationFileURL) ?? "false"
        titlebarStyle = readValue(for: "macos-titlebar-style", at: app.configurationFileURL) ?? "transparent"
        showTopbar = boolValue(for: "macos-topbar", at: app.configurationFileURL, default: false)
        quitAfterLastWindowCloses = config.shouldQuitAfterLastWindowClosed
        workingDirectory = readValue(for: "working-directory", at: app.configurationFileURL) ?? ""
        shellIntegration = readValue(for: "shell-integration", at: app.configurationFileURL) ?? "detect"
        copyOnSelect = readValue(for: "copy-on-select", at: app.configurationFileURL) ?? "none"
        mouseHideWhileTyping = boolValue(for: "mouse-hide-while-typing", at: app.configurationFileURL, default: false)
        scrollbackLimit = readValue(for: "scrollback-limit-bytes", at: app.configurationFileURL) ??
            readValue(for: "scrollback-limit", at: app.configurationFileURL) ?? "50MB"
        autoUpdate = readValue(for: "auto-update", at: app.configurationFileURL) ?? "check"
        updateChannel = readValue(for: "auto-update-channel", at: app.configurationFileURL) ?? "stable"
        optionAsAlt = readValue(for: "macos-option-as-alt", at: app.configurationFileURL) ?? ""
        autoSecureInput = boolValue(for: "macos-auto-secure-input", at: app.configurationFileURL, default: true)
        secureInputIndication = boolValue(for: "macos-secure-input-indication", at: app.configurationFileURL, default: true)
        isLoaded = true
    }

    func apply(to app: SpectrePro.App) {
        guard let url = app.configurationFileURL else {
            fail("Spectre Pro could not locate its configuration file.")
            return
        }

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let restartNeeded = requiresRestart(at: url)
            var contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            contents = replacing("theme", with: theme.trimmingCharacters(in: .whitespacesAndNewlines), in: contents)
            contents = replacing("font-family", with: fontFamily.trimmingCharacters(in: .whitespacesAndNewlines), in: contents)
            contents = replacing("font-size", with: String(format: "%.1f", fontSize), in: contents)
            contents = replacing("cursor-style", with: cursorStyle, in: contents)
            contents = replacing("background", with: backgroundColor.trimmingCharacters(in: .whitespacesAndNewlines), in: contents)
            contents = replacing("foreground", with: foregroundColor.trimmingCharacters(in: .whitespacesAndNewlines), in: contents)
            contents = replacing("background-opacity", with: String(format: "%.2f", backgroundOpacity), in: contents)
            contents = replacing("background-blur", with: backgroundBlur, in: contents)
            contents = replacing("window-save-state", with: windowSaveState, in: contents)
            contents = replacing("fullscreen", with: fullscreenMode, in: contents)
            contents = replacing("macos-non-native-fullscreen", with: fullscreenShortcutMode, in: contents)
            contents = replacing("macos-titlebar-style", with: titlebarStyle, in: contents)
            contents = replacing("macos-topbar", with: showTopbar ? "true" : "false", in: contents)
            contents = replacing("quit-after-last-window-closed", with: quitAfterLastWindowCloses ? "true" : "false", in: contents)
            contents = replacing("working-directory", with: workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines), in: contents)
            contents = replacing("shell-integration", with: shellIntegration, in: contents)
            contents = replacing("copy-on-select", with: copyOnSelect, in: contents)
            contents = replacing("mouse-hide-while-typing", with: mouseHideWhileTyping ? "true" : "false", in: contents)
            contents = replacing("scrollback-limit-bytes", with: scrollbackLimit.trimmingCharacters(in: .whitespacesAndNewlines), in: contents)
            contents = replacing("scrollback-limit", with: "", in: contents)
            contents = replacing("auto-update", with: autoUpdate, in: contents)
            contents = replacing("auto-update-channel", with: updateChannel, in: contents)
            contents = replacing("macos-option-as-alt", with: optionAsAlt, in: contents)
            contents = replacing("macos-auto-secure-input", with: autoSecureInput ? "true" : "false", in: contents)
            contents = replacing("macos-secure-input-indication", with: secureInputIndication ? "true" : "false", in: contents)
            try contents.write(to: url, atomically: true, encoding: .utf8)
            app.reloadConfig()
            didFail = false
            statusMessage = "Applied to \(url.path)."
            if restartNeeded {
                presentRestartPrompt()
            }
        } catch {
            fail("Could not save configuration: \(error.localizedDescription)")
        }
    }

    private var fullscreenShortcutMode: String {
        switch fullscreenMode {
        case "non-native":
            "true"
        case "non-native-visible-menu":
            "visible-menu"
        case "non-native-padded-notch":
            "padded-notch"
        default:
            "false"
        }
    }

    private func requiresRestart(at url: URL) -> Bool {
        backgroundOpacity != doubleValue(for: "background-opacity", at: url, default: 1) ||
            updateChannel != (readValue(for: "auto-update-channel", at: url) ?? "stable")
    }

    private func presentRestartPrompt() {
        let alert = NSAlert()
        alert.messageText = "Restart Spectre Pro to Apply All Changes?"
        alert.informativeText = "Background opacity and update channel changes require a restart. They are already saved and will apply the next time Spectre Pro opens."
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            restartApplication()
        }
    }

    private func restartApplication() {
        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        launcher.arguments = ["-n", Bundle.main.bundleURL.path]

        do {
            try launcher.run()
            NSApp.terminate(nil)
        } catch {
            fail("Settings were saved, but Spectre Pro could not restart: \(error.localizedDescription)")
        }
    }

    func loadReference(from app: SpectrePro.App) {
        guard referenceStatus == .idle, let executableURL = Bundle.main.executableURL else { return }
        referenceStatus = .loading
        let configurationURL = app.configurationFileURL

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let options = try Self.loadReference(executableURL: executableURL)
                let values = Self.readValues(at: configurationURL)
                DispatchQueue.main.async {
                    self?.reference = options
                    self?.optionValues = values
                    self?.referenceStatus = .ready
                }
            } catch {
                DispatchQueue.main.async {
                    self?.referenceStatus = .failed(error.localizedDescription)
                }
            }
        }
    }

    func value(for option: ConfigurationOption) -> Binding<String> {
        Binding(
            get: { self.optionValues[option.key] ?? "" },
            set: { self.optionValues[option.key] = $0 }
        )
    }

    func apply(option: ConfigurationOption, to app: SpectrePro.App) {
        guard let url = app.configurationFileURL else {
            fail("Spectre Pro could not locate its configuration file.")
            return
        }

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let value = optionValues[option.key] ?? ""
            try replacingAll(option.key, with: value, in: contents).write(to: url, atomically: true, encoding: .utf8)
            app.reloadConfig()
            didFail = false
            statusMessage = "Applied \(option.key)."
        } catch {
            fail("Could not save configuration: \(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) {
        didFail = true
        statusMessage = message
    }

    private func readValue(for key: String, at url: URL?) -> String? {
        guard let url, let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return contents
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reversed()
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: "=") else { return nil }
                guard trimmed[..<separator].trimmingCharacters(in: .whitespaces) == key else { return nil }
                return normalizedValue(String(trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)))
            }
            .first
    }

    private func normalizedValue(_ value: String) -> String {
        guard value.count >= 2, value.first == "\"", value.last == "\"" else { return value }
        return String(value.dropFirst().dropLast())
    }

    private func boolValue(for key: String, at url: URL?, default defaultValue: Bool) -> Bool {
        switch readValue(for: key, at: url)?.lowercased() {
        case "true": true
        case "false": false
        default: defaultValue
        }
    }

    private func doubleValue(for key: String, at url: URL?, default defaultValue: Double) -> Double {
        guard let value = readValue(for: key, at: url), let result = Double(value) else { return defaultValue }
        return result
    }

    nonisolated private static func readValues(at url: URL?) -> [String: String] {
        guard let url, let contents = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var values = [String: [String]]()

        for line in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            values[key, default: []].append(value)
        }

        return values.mapValues { $0.joined(separator: "\n") }
    }

    nonisolated private static func loadReference(executableURL: URL) throws -> [ConfigurationOption] {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["+show-config", "--default", "--docs"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else {
            throw ConfigurationReferenceError.unavailable
        }

        var options = [ConfigurationOption]()
        var documentation = [String]()

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("#") {
                let text = line.dropFirst().trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { documentation.append(text) }
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let separator = trimmed.firstIndex(of: "="), !trimmed.hasPrefix("#") else {
                if trimmed.isEmpty { documentation.removeAll() }
                continue
            }

            let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { continue }
            if !options.contains(where: { $0.key == key }) {
                options.append(.init(key: key, documentation: documentation.joined(separator: " ")))
            }
            documentation.removeAll()
        }

        return options.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    private func replacing(_ key: String, with value: String, in contents: String) -> String {
        var lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var lastMatch: Int?

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: "=") else { continue }
            guard trimmed[..<separator].trimmingCharacters(in: .whitespaces) == key else { continue }
            lastMatch = index
        }

        if value.isEmpty {
            if let lastMatch {
                lines.remove(at: lastMatch)
            }
            return lines.joined(separator: "\n")
        }

        let assignment = "\(key) = \(value)"
        if let lastMatch {
            lines[lastMatch] = assignment
        } else {
            if !lines.isEmpty, !lines.last!.isEmpty { lines.append("") }
            lines.append(assignment)
        }

        return lines.joined(separator: "\n")
    }

    private func replacingAll(_ key: String, with value: String, in contents: String) -> String {
        let existingLines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var lines = [String]()
        var firstMatch: Int?

        for line in existingLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: "=") else {
                lines.append(line)
                continue
            }
            let matches = trimmed[..<separator].trimmingCharacters(in: .whitespaces) == key
            if matches {
                if firstMatch == nil { firstMatch = lines.count }
            } else {
                lines.append(line)
            }
        }

        let assignments = value
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { "\(key) = \($0.trimmingCharacters(in: .whitespacesAndNewlines))" }

        guard !assignments.isEmpty else { return lines.joined(separator: "\n") }
        let insertionIndex = min(firstMatch ?? lines.count, lines.count)
        lines.insert(contentsOf: assignments, at: insertionIndex)
        return lines.joined(separator: "\n")
    }
}

private enum ReferenceStatus: Equatable {
    case idle
    case loading
    case ready
    case failed(String)
}

private enum ConfigurationReferenceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "The bundled configuration reference is unavailable."
    }
}

private struct ConfigurationOption: Identifiable {
    let key: String
    let documentation: String

    var id: String { key }
    var category: ConfigurationCategory { .forKey(key) }
    var label: String { key.replacingOccurrences(of: "-", with: " ").capitalized }
}

private enum ConfigurationCategory: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case typography = "Typography"
    case cursorAndSelection = "Cursor & Selection"
    case terminal = "Terminal"
    case windowAndMacOS = "Window & macOS"
    case keyboardAndCommands = "Keyboard & Commands"
    case privacyAndUpdates = "Privacy & Updates"
    case advanced = "Advanced"

    var id: String { rawValue }

    static func forKey(_ key: String) -> Self {
        switch key {
        case let key where key.hasPrefix("font-") || key.hasPrefix("adjust-") || key.hasPrefix("grapheme-") || key.hasPrefix("freetype-"):
            .typography
        case let key where key.hasPrefix("cursor-") || key.hasPrefix("mouse-") || key.hasPrefix("selection-") || key == "copy-on-select":
            .cursorAndSelection
        case let key where key.hasPrefix("window-") || key.hasPrefix("macos-") || key.hasPrefix("fullscreen") || key.hasPrefix("quick-terminal"):
            .windowAndMacOS
        case let key where key.hasPrefix("keybind") || key.hasPrefix("command") || key.hasPrefix("shell-") || key == "working-directory":
            .keyboardAndCommands
        case let key where key.hasPrefix("clipboard-") || key.hasPrefix("auto-update") || key.hasPrefix("confirm-") || key.hasPrefix("security-"):
            .privacyAndUpdates
        case let key where key == "theme" || key == "background" || key == "foreground" || key == "palette" || key.hasPrefix("background-") || key.hasPrefix("selection-") || key.hasPrefix("minimum-contrast") || key.hasPrefix("alpha-"):
            .appearance
        case let key where key.hasPrefix("scroll") || key.hasPrefix("bell") || key.hasPrefix("image") || key.hasPrefix("link") || key.hasPrefix("custom-") || key.hasPrefix("osc-"):
            .terminal
        default:
            .advanced
        }
    }
}

private struct ConfigurationReferenceView: View {
    @ObservedObject var configuration: ConfigurationSettingsModel
    let app: SpectrePro.App
    @State private var category: ConfigurationCategory?
    @State private var search = ""

    var body: some View {
        Group {
            switch configuration.referenceStatus {
            case .idle, .loading:
                ProgressView("Loading configuration reference…")
            case .failed(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Configuration Reference Unavailable")
                        .font(.headline)
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            case .ready:
                NavigationSplitView {
                    List(ConfigurationCategory.allCases, selection: $category) { category in
                        Label(category.rawValue, systemImage: icon(for: category))
                            .tag(category)
                    }
                    .navigationTitle("Settings")
                } detail: {
                    List(filteredOptions) { option in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(option.label)
                                    .font(.headline)
                                Spacer()
                                Text(option.key)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            if !option.documentation.isEmpty {
                                Text(option.documentation)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            TextEditor(text: configuration.value(for: option))
                                .font(.body.monospaced())
                                .frame(minHeight: 28, maxHeight: 60)
                                .overlay(alignment: .topLeading) {
                                    if configuration.value(for: option).wrappedValue.isEmpty {
                                        Text("Default value")
                                            .foregroundStyle(.tertiary)
                                            .padding(.top, 6)
                                            .padding(.leading, 5)
                                            .allowsHitTesting(false)
                                    }
                                }

                            HStack {
                                Text("One value per line for repeatable settings.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Button("Apply") {
                                    configuration.apply(option: option, to: app)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .navigationTitle(category?.rawValue ?? "All Settings")
                    .searchable(text: $search, prompt: "Search settings")
                }
            }
        }
        .task {
            configuration.loadReference(from: app)
        }
    }

    private var filteredOptions: [ConfigurationOption] {
        configuration.reference.filter { option in
            let belongsToCategory = category == nil || option.category == category
            let matchesSearch = search.isEmpty || option.key.localizedCaseInsensitiveContains(search) || option.documentation.localizedCaseInsensitiveContains(search)
            return belongsToCategory && matchesSearch
        }
    }

    private func icon(for category: ConfigurationCategory) -> String {
        switch category {
        case .appearance: "paintpalette"
        case .typography: "textformat"
        case .cursorAndSelection: "cursorarrow"
        case .terminal: "terminal"
        case .windowAndMacOS: "macwindow"
        case .keyboardAndCommands: "command"
        case .privacyAndUpdates: "lock"
        case .advanced: "slider.horizontal.3"
        }
    }
}

final class ConfigurationStudioController: NSWindowController {
    static let shared = ConfigurationStudioController()

    func show(appDelegate: AppDelegate) {
        if window == nil {
            let contentView = NSHostingView(
                rootView: SettingsView().environmentObject(appDelegate)
            )
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Spectre Pro Settings"
            settingsWindow.contentView = contentView
            settingsWindow.minSize = NSSize(width: 580, height: 430)
            settingsWindow.center()
            window = settingsWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
