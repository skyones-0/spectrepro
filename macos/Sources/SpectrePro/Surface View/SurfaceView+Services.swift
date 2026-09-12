import AppKit
import SpectreProKit

extension SpectrePro.SurfaceView: NSServicesMenuRequestor {
    override func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?,
        returnType: NSPasteboard.PasteboardType?
    ) -> Any? {
        let supportedTypes: [NSPasteboard.PasteboardType] = [.string, .init("public.utf8-plain-text")]
        guard returnType == nil || supportedTypes.contains(returnType!),
              sendType == nil || supportedTypes.contains(sendType!) else {
            return super.validRequestor(forSendType: sendType, returnType: returnType)
        }

        if let sendType, supportedTypes.contains(sendType),
           surface == nil || !spectrepro_surface_has_selection(surface) {
            return super.validRequestor(forSendType: sendType, returnType: returnType)
        }

        return self
    }

    func writeSelection(to pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        guard let surface else { return false }
        var text = spectrepro_text_s()
        guard spectrepro_surface_read_selection(surface, &text) else { return false }
        defer { spectrepro_surface_free_text(surface, &text) }

        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(String(cString: text.text), forType: .string)
        return true
    }

    func readSelection(from pasteboard: NSPasteboard) -> Bool {
        guard let string = pasteboard.getOpinionatedStringContents() else { return false }
        let length = string.utf8CString.count
        guard length > 0 else { return true }
        string.withCString { pointer in
            spectrepro_surface_text(surface, pointer, UInt(length - 1))
        }
        return true
    }
}
