import AppKit
import CoreTransferable
import UniformTypeIdentifiers

/// Conformance to `Transferable` enables drag-and-drop.
extension SpectrePro.SurfaceView: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .spectreproSurfaceId) { surface in
            withUnsafeBytes(of: surface.id.uuid) { Data($0) }
        } importing: { data in
            guard data.count == 16 else {
                throw TransferError.invalidData
            }

            let uuid = data.withUnsafeBytes {
                $0.load(as: UUID.self)
            }

            guard let imported = await Self.find(uuid: uuid) else {
                throw TransferError.invalidData
            }

            return imported
        }
    }

    enum TransferError: Error {
        case invalidData
    }

    @MainActor
    static func find(uuid: UUID) -> Self? {
        guard let del = NSApp.delegate as? SpectrePro.Delegate else { return nil }
        return del.spectreproSurface(id: uuid) as? Self
    }
}

extension UTType {
    /// A format that encodes the bare UUID only for the surface. This can be used if you have
    /// a way to look up a surface by ID.
    static let spectreproSurfaceId = UTType(exportedAs: "co.skyones.spectreproSurfaceId")
}

extension NSPasteboard.PasteboardType {
    /// Pasteboard type for dragging surface IDs.
    static let spectreproSurfaceId = NSPasteboard.PasteboardType(UTType.spectreproSurfaceId.identifier)
}
