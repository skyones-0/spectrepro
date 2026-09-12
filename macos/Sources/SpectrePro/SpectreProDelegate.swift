import Foundation

extension SpectrePro {
    /// This is a delegate that should be applied to your global app delegate for SpectreProKit
    /// to perform app-global operations.
    protocol Delegate {
        /// Look up a surface within the application by ID.
        func spectreproSurface(id: UUID) -> SurfaceView?
    }
}
