import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @StateObject private var configuration = ConfigurationSettingsModel()

    var body: some View {
        TabView {
            AppearanceSettingsTab(configuration: configuration) {
                configuration.apply(to: appDelegate.spectrepro)
            }
            .tabItem { Label("Appearance", systemImage: "paintpalette") }

            TerminalSettingsTab(configuration: configuration) {
                configuration.apply(to: appDelegate.spectrepro)
            }
            .tabItem { Label("Terminal", systemImage: "terminal") }

            WindowSettingsTab(configuration: configuration) {
                configuration.apply(to: appDelegate.spectrepro)
            }
            .tabItem { Label("Window", systemImage: "macwindow") }

            PrivacySettingsTab(configuration: configuration) {
                configuration.apply(to: appDelegate.spectrepro)
            }
            .tabItem { Label("Privacy", systemImage: "lock") }

            ConfigurationReferenceView(
                configuration: configuration,
                app: appDelegate.spectrepro,
                openConfiguration: { appDelegate.openConfig(nil) },
                reloadConfiguration: { appDelegate.reloadConfig(nil) }
            )
                .tabItem { Label("All Settings", systemImage: "list.bullet.rectangle") }
        }
        .task {
            configuration.load(from: appDelegate.spectrepro)
            configuration.loadReference(from: appDelegate.spectrepro)
            configuration.loadThemes()
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 460, idealHeight: 520)
    }
}

private struct AppearanceSettingsTab: View {
    @ObservedObject var configuration: ConfigurationSettingsModel
    let apply: () -> Void
    @State private var showsCustomThemeInput = false

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: $configuration.theme) {
                    Text("System Default").tag("")
                    Section("Featured themes") {
                        ForEach(configuration.featuredThemes, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                    Section("All bundled themes") {
                        ForEach(configuration.otherAvailableThemes, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                }
                .pickerStyle(.menu)
                .disabled(configuration.availableThemes.isEmpty)

                switch configuration.themeStatus {
                case .loading:
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading bundled themes…")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                case .failed(let message):
                    HStack {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Spacer()
                        Button("Retry") { configuration.loadThemes(force: true) }
                            .controlSize(.small)
                    }
                case .ready:
                    Text("Choose one of the bundled themes. Custom colors override a theme.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .idle:
                    EmptyView()
                }

                DisclosureGroup("Use a custom theme file", isExpanded: $showsCustomThemeInput) {
                    TextField("Theme file path or custom theme name", text: $configuration.theme)
                        .textFieldStyle(.roundedBorder)
                    Text("Use this only for a theme outside the bundled collection.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if configuration.hasThemeColorOverrides {
                    Button("Use Theme Colors") {
                        configuration.clearThemeColorOverrides()
                    }
                    .help("Clear background, foreground, and palette overrides when you apply changes.")
                }
            }

            Section("Typography") {
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
            }

            Section("Colors & Material") {
                HStack {
                    TextField("Background Color", text: $configuration.backgroundColor, prompt: Text("#1E1E1E"))
                        .textFieldStyle(.roundedBorder)
                    ConfigurationColorPicker(value: $configuration.backgroundColor, label: "Background Color")
                }

                HStack {
                    TextField("Foreground Color", text: $configuration.foregroundColor, prompt: Text("#FFFFFF"))
                        .textFieldStyle(.roundedBorder)
                    ConfigurationColorPicker(value: $configuration.foregroundColor, label: "Foreground Color")
                }

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

            SettingsApplyBar(configuration: configuration, apply: apply)
        }
        .formStyle(.grouped)
        .padding(.horizontal)
        .onAppear {
            showsCustomThemeInput = configuration.usesCustomTheme
        }
    }

}

private struct TerminalSettingsTab: View {
    @ObservedObject var configuration: ConfigurationSettingsModel
    let apply: () -> Void

    var body: some View {
        Form {
            Section("Shell") {
                TextField("Working Directory", text: $configuration.workingDirectory, prompt: Text("Home directory"))
                    .textFieldStyle(.roundedBorder)

                Picker("Shell Integration", selection: $configuration.shellIntegration) {
                    Text("Automatic").tag("detect")
                    Text("Disabled").tag("none")
                }
            }

            Section("Interaction") {
                Picker("Copy on Select", selection: $configuration.copyOnSelect) {
                    Text("Disabled").tag("none")
                    Text("Clipboard").tag("clipboard")
                    Text("Primary Selection").tag("primary")
                }

                Toggle("Hide pointer while typing", isOn: $configuration.mouseHideWhileTyping)
            }

            Section("History") {
                TextField("Scrollback Limit", text: $configuration.scrollbackLimit, prompt: Text("50MB"))
                    .textFieldStyle(.roundedBorder)

                Text("Examples: 50MB, 1GB, or a number of bytes. A larger history uses more memory and applies to new terminals.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsApplyBar(configuration: configuration, apply: apply)
        }
        .formStyle(.grouped)
        .padding(.horizontal)
    }
}

private struct WindowSettingsTab: View {
    @ObservedObject var configuration: ConfigurationSettingsModel
    let apply: () -> Void

    var body: some View {
        Form {
            Section("New Windows") {
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
            }

            Section("Title Bar") {
                Picker("Style", selection: $configuration.titlebarStyle) {
                    Text("Native").tag("native")
                    Text("Transparent").tag("transparent")
                    Text("Tabs").tag("tabs")
                    Text("Hidden").tag("hidden")
                }

                Toggle("Show top bar", isOn: $configuration.showTopbar)

                Text("Title bar and fullscreen preferences apply to new windows.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("App Lifecycle") {
                Toggle("Quit when the last window closes", isOn: $configuration.quitAfterLastWindowCloses)
            }

            SettingsApplyBar(configuration: configuration, apply: apply)
        }
        .formStyle(.grouped)
        .padding(.horizontal)
    }
}

private struct PrivacySettingsTab: View {
    @ObservedObject var configuration: ConfigurationSettingsModel
    let apply: () -> Void

    var body: some View {
        Form {
            Section("Updates") {
                Picker("Automatic Updates", selection: $configuration.autoUpdate) {
                    Text("Off").tag("off")
                    Text("Check and Notify").tag("check")
                    Text("Download and Notify").tag("download")
                }

                Picker("Update Channel", selection: $configuration.updateChannel) {
                    Text("Stable").tag("stable")
                    Text("Preview").tag("tip")
                }

                Text("Updates are never installed without confirmation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard Privacy") {
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

            Section("Diagnostics") {
                Picker("Log detail", selection: $configuration.verbosityLevel) {
                    Text("Errors only").tag(AppDiagnostics.Verbosity.errorsOnly)
                    Text("Normal").tag(AppDiagnostics.Verbosity.normal)
                    Text("Verbose").tag(AppDiagnostics.Verbosity.verbose)
                }
                Text("Changes take effect immediately and do not require a restart.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsApplyBar(configuration: configuration, apply: apply)
        }
        .formStyle(.grouped)
        .padding(.horizontal)
    }
}

private struct SettingsApplyBar: View {
    @ObservedObject var configuration: ConfigurationSettingsModel
    let apply: () -> Void

    var body: some View {
        Section {
            HStack {
                Button("Apply Changes", action: apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!configuration.isLoaded)

                if let status = configuration.statusMessage {
                    Text(status)
                        .foregroundStyle(configuration.didFail ? .red : .secondary)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

@MainActor
private final class ConfigurationSettingsModel: ObservableObject {
    private static let featuredThemeNames = [
        "Catppuccin Latte",
        "Catppuccin Macchiato",
        "Catppuccin Mocha",
        "TokyoNight",
        "TokyoNight Day",
        "Dracula",
        "Nord",
        "Gruvbox Dark",
        "Gruvbox Light",
        "Ayu Light",
        "Ayu Mirage",
        "Material",
        "Material Ocean",
        "Night Owl",
        "GitHub Dark",
        "Xcode Dark",
        "Builtin Dark",
        "Horizon",
        "Cobalt2",
        "Tomorrow Night",
    ]

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
    @Published var verbosityLevel = AppDiagnostics.verbosity
    @Published private(set) var isLoaded = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var didFail = false
    @Published private(set) var reference = [ConfigurationOption]()
    @Published private(set) var referenceStatus: ReferenceStatus = .idle
    @Published private(set) var availableThemes = [String]()
    @Published private(set) var themeStatus: ThemeStatus = .idle
    @Published private var optionValues = [String: String]()
    @Published private(set) var hasThemeColorOverrides = false
    private var loadedValues = [String: String]()
    private var loadedOptionValues = [String: String]()
    private var clearsThemePalette = false

    var featuredThemes: [String] {
        Self.featuredThemeNames.filter(availableThemes.contains)
    }

    var otherAvailableThemes: [String] {
        availableThemes.filter { !Self.featuredThemeNames.contains($0) }
    }

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
        verbosityLevel = AppDiagnostics.verbosity
        hasThemeColorOverrides = Self.hasThemeColorOverrides(at: app.configurationFileURL)
        clearsThemePalette = false
        loadedValues = currentValues
        isLoaded = true

        let source = app.configurationFileURL?.path ?? "default configuration"
        AppDiagnostics.event("Loaded settings from \(source).", category: "Settings")
    }

    func loadThemes(force: Bool = false) {
        guard (force || availableThemes.isEmpty), let executableURL = Bundle.main.executableURL else { return }
        themeStatus = .loading

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let themes = Self.loadThemes(executableURL: executableURL)
            DispatchQueue.main.async {
                guard let self else { return }
                if themes.isEmpty {
                    self.themeStatus = .failed("Bundled themes could not be loaded.")
                } else {
                    self.availableThemes = themes
                    self.themeStatus = .ready
                    AppDiagnostics.event("Loaded \(themes.count) bundled themes.", category: "Settings")
                }
            }
        }
    }

    func apply(to app: SpectrePro.App) {
        guard let url = app.configurationFileURL else {
            fail("Spectre Pro could not locate its configuration file.")
            return
        }

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let invalidColors = ["background", "foreground"].filter {
                let value = currentValues[$0] ?? ""
                return !value.isEmpty && !ConfigurationColor.isValidHex(value)
            }
            guard invalidColors.isEmpty else {
                fail("Invalid color value for \(invalidColors.joined(separator: ", ")). Use #RRGGBB.")
                return
            }
            let restartNeeded = requiresRestart(at: url)
            var contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let values = currentValues
            let changedKeys = values.keys.filter { values[$0] != loadedValues[$0] }

            guard !changedKeys.isEmpty || clearsThemePalette else {
                didFail = false
                statusMessage = "No changes to apply."
                AppDiagnostics.event("Skipped settings save because no values changed.", category: "Settings")
                return
            }

            for key in changedKeys {
                contents = replacing(key, with: values[key] ?? "", in: contents)
            }
            if changedKeys.contains("scrollback-limit-bytes") {
                contents = replacing("scrollback-limit", with: "", in: contents)
            }
            if clearsThemePalette {
                contents = replacingAll("palette", with: "", in: contents)
            }
            try contents.write(to: url, atomically: true, encoding: .utf8)
            app.reloadConfig()
            AppDiagnostics.verbosity = verbosityLevel
            didFail = false
            statusMessage = "Applied to \(url.path)."
            loadedValues = values
            clearsThemePalette = false
            hasThemeColorOverrides = Self.hasThemeColorOverrides(at: url)
            AppDiagnostics.event("Applied settings: \(changedKeys.sorted().joined(separator: ", ")).", category: "Settings")
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

    func clearThemeColorOverrides() {
        backgroundColor = ""
        foregroundColor = ""
        clearsThemePalette = true
        AppDiagnostics.event("Marked theme color overrides for removal.", category: "Settings")
    }

    var usesCustomTheme: Bool {
        !theme.isEmpty && !availableThemes.contains(theme)
    }

    private var currentValues: [String: String] {
        [
            "theme": theme.trimmingCharacters(in: .whitespacesAndNewlines),
            "font-family": fontFamily.trimmingCharacters(in: .whitespacesAndNewlines),
            "font-size": String(format: "%.1f", fontSize),
            "cursor-style": cursorStyle,
            "background": backgroundColor.trimmingCharacters(in: .whitespacesAndNewlines),
            "foreground": foregroundColor.trimmingCharacters(in: .whitespacesAndNewlines),
            "background-opacity": String(format: "%.2f", backgroundOpacity),
            "background-blur": backgroundBlur,
            "window-save-state": windowSaveState,
            "fullscreen": fullscreenMode,
            "macos-non-native-fullscreen": fullscreenShortcutMode,
            "macos-titlebar-style": titlebarStyle,
            "macos-topbar": showTopbar ? "true" : "false",
            "quit-after-last-window-closed": quitAfterLastWindowCloses ? "true" : "false",
            "working-directory": workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines),
            "shell-integration": shellIntegration,
            "copy-on-select": copyOnSelect,
            "mouse-hide-while-typing": mouseHideWhileTyping ? "true" : "false",
            "scrollback-limit-bytes": scrollbackLimit.trimmingCharacters(in: .whitespacesAndNewlines),
            "auto-update": autoUpdate,
            "auto-update-channel": updateChannel,
            "macos-option-as-alt": optionAsAlt,
            "macos-auto-secure-input": autoSecureInput ? "true" : "false",
            "macos-secure-input-indication": secureInputIndication ? "true" : "false",
        ]
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
        refreshReferenceValues(from: app)
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
                    self?.loadedOptionValues = values
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

    func colorValue(for option: ConfigurationOption) -> Binding<String> {
        Binding(
            get: { self.optionValues[option.key] ?? "" },
            set: { self.optionValues[option.key] = $0 }
        )
    }

    func refreshReferenceValues(from app: SpectrePro.App) {
        optionValues = Self.readValues(at: app.configurationFileURL)
        loadedOptionValues = optionValues
    }

    var hasUnsavedReferenceChanges: Bool {
        optionValues != loadedOptionValues
    }

    func apply(option: ConfigurationOption, to app: SpectrePro.App) {
        guard let url = app.configurationFileURL else {
            fail("Spectre Pro could not locate its configuration file.")
            return
        }

        let value = optionValues[option.key] ?? ""
        if ConfigurationColor.supports(option.key), !value.isEmpty, !ConfigurationColor.isValidHex(value) {
            fail("Invalid color value for \(option.key). Use #RRGGBB.")
            return
        }

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            try replacingAll(option.key, with: value, in: contents).write(to: url, atomically: true, encoding: .utf8)
            app.reloadConfig()
            didFail = false
            statusMessage = "Applied \(option.key)."
            loadedOptionValues = optionValues
            AppDiagnostics.event("Applied advanced setting \(option.key).", category: "Settings")
        } catch {
            fail("Could not save configuration: \(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) {
        didFail = true
        statusMessage = message
        AppDiagnostics.error(message, category: "Settings")
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
                return Self.normalizedValue(String(trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)))
            }
            .first
    }

    nonisolated private static func normalizedValue(_ value: String) -> String {
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
            let value = Self.normalizedValue(String(trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)))
            values[key, default: []].append(value)
        }

        return values.mapValues { $0.joined(separator: "\n") }
    }

    nonisolated private static func hasThemeColorOverrides(at url: URL?) -> Bool {
        let values = readValues(at: url)
        return ["background", "foreground", "palette"].contains { key in
            !(values[key] ?? "").isEmpty
        }
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

        if !options.contains(where: { $0.key == "quick-terminal-size" }) {
            options.append(.init(
                key: "quick-terminal-size",
                documentation: "Size of the quick terminal as width,height. This option has no default value."
            ))
        }

        return options.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    nonisolated private static func loadThemes(executableURL: URL) -> [String] {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["+list-themes"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8) else { return [] }

            return text
                .split(separator: "\n")
                .compactMap { line in
                    let name = String(line)
                    guard let separator = name.range(of: " (", options: .backwards),
                          name.hasSuffix(")") else { return nil }
                    return String(name[..<separator.lowerBound])
                }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        } catch {
            return []
        }
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

private enum ThemeStatus: Equatable {
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
    let openConfiguration: () -> Void
    let reloadConfiguration: () -> Void
    @State private var category: ConfigurationCategory?
    @State private var search = ""
    @State private var showsRefreshConfirmation = false

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

                            if ConfigurationColor.supports(option.key) {
                                HStack {
                                    Text("Color")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ConfigurationColorPicker(
                                        value: configuration.colorValue(for: option),
                                        label: option.label
                                    )
                                    Spacer()
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
                    .toolbar {
                        ToolbarItemGroup {
                            Button("Open Config", systemImage: "doc") {
                                openConfiguration()
                            }

                            Button("Reload", systemImage: "arrow.triangle.2.circlepath") {
                                reloadConfiguration()
                                configuration.refreshReferenceValues(from: app)
                            }

                            Button("Refresh Values", systemImage: "arrow.clockwise") {
                                if configuration.hasUnsavedReferenceChanges {
                                    showsRefreshConfirmation = true
                                } else {
                                    configuration.refreshReferenceValues(from: app)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            configuration.loadReference(from: app)
            configuration.refreshReferenceValues(from: app)
        }
        .alert("Discard unsaved settings edits?", isPresented: $showsRefreshConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Refresh", role: .destructive) {
                configuration.refreshReferenceValues(from: app)
            }
        } message: {
            Text("Refreshing values will replace the changes currently entered in All Settings.")
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
