import SpectreProKit

extension FullscreenMode {
    /// Initialize from a SpectrePro fullscreen action.
    static func from(spectrepro: spectrepro_action_fullscreen_e) -> Self? {
        return switch spectrepro {
        case SPECTREPRO_FULLSCREEN_NATIVE:
                .native

        case SPECTREPRO_FULLSCREEN_MACOS_NON_NATIVE:
                .nonNative

        case SPECTREPRO_FULLSCREEN_MACOS_NON_NATIVE_VISIBLE_MENU:
                .nonNativeVisibleMenu

        case SPECTREPRO_FULLSCREEN_MACOS_NON_NATIVE_PADDED_NOTCH:
                .nonNativePaddedNotch

        default:
            nil
        }
    }
}
