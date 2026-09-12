import AppKit

// MARK: SpectrePro Delegate

/// This implements the SpectrePro app delegate protocol which is used by the SpectrePro
/// APIs for app-global information.
extension AppDelegate: SpectrePro.Delegate {
    func spectreproSurface(id: UUID) -> SpectrePro.SurfaceView? {
        for window in NSApp.windows {
            guard let controller = window.windowController as? BaseTerminalController else {
                continue
            }

            for surface in controller.surfaceTree where surface.id == id {
                return surface
            }
        }

        return nil
    }
}
