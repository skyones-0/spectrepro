import AppKit
import CoreText
import SpectreProKit

extension SpectrePro.SurfaceView: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(pasteSelection):
            guard let string = NSPasteboard.spectreproSelection.getOpinionatedStringContents() else { return false }
            return !string.isEmpty
        case #selector(findHide):
            return searchState != nil
        case #selector(toggleReadonly):
            item.state = readonly ? .on : .off
            return true
        case #selector(copy(_:)):
            return !(accessibilitySelectedText()?.isEmpty ?? true)
        default:
            return true
        }
    }
}

extension SpectrePro.SurfaceView {
    override func isAccessibilityElement() -> Bool { true }

    override func accessibilityRole() -> NSAccessibility.Role? { .textArea }

    override func accessibilityHelp() -> String? { "Terminal content area" }

    override func accessibilityValue() -> Any? { cachedScreenContents.get() }

    override func accessibilitySelectedTextRange() -> NSRange { selectedRange() }

    override func accessibilitySelectedText() -> String? {
        guard let surface else { return nil }
        var text = spectrepro_text_s()
        guard spectrepro_surface_read_selection(surface, &text) else { return nil }
        defer { spectrepro_surface_free_text(surface, &text) }
        let string = String(cString: text.text)
        return string.isEmpty ? nil : string
    }

    override func accessibilityNumberOfCharacters() -> Int { cachedScreenContents.get().count }

    override func accessibilityVisibleCharacterRange() -> NSRange {
        NSRange(location: 0, length: cachedScreenContents.get().count)
    }

    override func accessibilityLine(for index: Int) -> Int {
        String(cachedScreenContents.get().prefix(index)).components(separatedBy: .newlines).count - 1
    }

    override func accessibilityString(for range: NSRange) -> String? {
        let content = cachedScreenContents.get()
        guard let swiftRange = Range(range, in: content) else { return nil }
        return String(content[swiftRange])
    }

    override func accessibilityAttributedString(for range: NSRange) -> NSAttributedString? {
        guard let surface, let string = accessibilityString(for: range) else { return nil }
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let fontRaw = spectrepro_surface_quicklook_font(surface) {
            let font = Unmanaged<CTFont>.fromOpaque(fontRaw)
            attributes[.font] = font.takeUnretainedValue()
            font.release()
        }
        return NSAttributedString(string: string, attributes: attributes)
    }
}
