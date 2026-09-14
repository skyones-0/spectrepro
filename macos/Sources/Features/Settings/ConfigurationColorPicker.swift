import AppKit
import SwiftUI

struct ConfigurationColorPicker: View {
    @Binding var value: String
    let label: String

    var body: some View {
        ColorPicker(
            label,
            selection: Binding(
                get: { ConfigurationColor.hex(value) },
                set: { value = ConfigurationColor.string($0) }
            ),
            supportsOpacity: false
        )
        .labelsHidden()
        .disabled(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !ConfigurationColor.isValidHex(value))
        .help("Choose \(label)")
    }
}

enum ConfigurationColor {
    static let keys: Set<String> = [
        "background",
        "foreground",
        "selection-foreground",
        "selection-background",
        "cursor-color",
        "cursor-text",
        "unfocused-split-fill",
        "split-divider-color",
        "search-foreground",
        "search-background",
        "search-selected-foreground",
        "search-selected-background",
        "window-titlebar-background",
        "window-titlebar-foreground",
        "bold-color",
        "macos-icon-ghost-color",
    ]

    static func supports(_ key: String) -> Bool {
        keys.contains(key)
    }

    static func isValidHex(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexadecimal = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        return hexadecimal.count == 6 && UInt64(hexadecimal, radix: 16) != nil
    }

    static func hex(_ value: String) -> Color {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexadecimal = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard isValidHex(value), let number = UInt64(hexadecimal, radix: 16) else {
            return .clear
        }

        return Color(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }

    static func string(_ color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return "#000000" }
        return String(
            format: "#%02X%02X%02X",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded())
        )
    }
}
