import os
import SwiftUI
import SpectreProKit

// MARK: C Extensions

extension SpectrePro {
    // The user notification category identifier
    static let userNotificationCategory = "co.skyones.spectrepro.userNotification"

    // The user notification "Show" action
    static let userNotificationActionShow = "co.skyones.spectrepro.userNotification.Show"
}

// MARK: Build Info

extension SpectrePro {
    struct Info {
        var mode: spectrepro_build_mode_e
        var version: String
    }

    static var info: Info {
        let raw = spectrepro_info()
        let version = NSString(
            bytes: raw.version,
            length: Int(raw.version_len),
            encoding: NSUTF8StringEncoding
        ) ?? "unknown"

        return Info(mode: raw.build_mode, version: String(version))
    }
}

// MARK: General Helpers

extension SpectrePro {
    enum LaunchSource: String {
        case cli
        case app
        case zig_run
    }

    /// Returns the mechanism that launched the app. This is based on an env var so
    /// its up to the env var being set in the correct circumstance.
    static var launchSource: LaunchSource {
        guard let envValue = ProcessInfo.processInfo.environment["SPECTREPRO_MAC_LAUNCH_SOURCE"] else {
            // We default to the CLI because the app bundle always sets the
            // source. If its unset we assume we're in a CLI environment.
            return .cli
        }

        // If the env var is set but its unknown then we default back to the app.
        return LaunchSource(rawValue: envValue) ?? .app
    }
}

// MARK: Swift Types for C Types

extension SpectrePro {
    class AllocatedString {
        private let cString: spectrepro_string_s

        init(_ c: spectrepro_string_s) {
            self.cString = c
        }

        var string: String {
            guard let ptr = cString.ptr else { return "" }
            let data = Data(bytes: ptr, count: Int(cString.len))
            return String(data: data, encoding: .utf8) ?? ""
        }

        deinit {
            spectrepro_string_free(cString)
        }
    }
}

extension SpectrePro {
    enum SetFloatWIndow {
        case on
        case off
        case toggle

        static func from(_ c: spectrepro_action_float_window_e) -> Self? {
            switch c {
            case SPECTREPRO_FLOAT_WINDOW_ON:
                return .on

            case SPECTREPRO_FLOAT_WINDOW_OFF:
                return .off

            case SPECTREPRO_FLOAT_WINDOW_TOGGLE:
                return .toggle

            default:
                return nil
            }
        }
    }

    enum SetSecureInput {
        case on
        case off
        case toggle

        static func from(_ c: spectrepro_action_secure_input_e) -> Self? {
            switch c {
            case SPECTREPRO_SECURE_INPUT_ON:
                return .on

            case SPECTREPRO_SECURE_INPUT_OFF:
                return .off

            case SPECTREPRO_SECURE_INPUT_TOGGLE:
                return .toggle

            default:
                return nil
            }
        }
    }

    /// An enum that is used for the directions that a split focus event can change.
    enum SplitFocusDirection {
        case previous, next, up, down, left, right

        /// Initialize from a SpectrePro API enum.
        static func from(direction: spectrepro_action_goto_split_e) -> Self? {
            switch direction {
            case SPECTREPRO_GOTO_SPLIT_PREVIOUS:
                return .previous

            case SPECTREPRO_GOTO_SPLIT_NEXT:
                return .next

            case SPECTREPRO_GOTO_SPLIT_UP:
                return .up

            case SPECTREPRO_GOTO_SPLIT_DOWN:
                return .down

            case SPECTREPRO_GOTO_SPLIT_LEFT:
                return .left

            case SPECTREPRO_GOTO_SPLIT_RIGHT:
                return .right

            default:
                return nil
            }
        }

        func toNative() -> spectrepro_action_goto_split_e {
            switch self {
            case .previous:
                return SPECTREPRO_GOTO_SPLIT_PREVIOUS

            case .next:
                return SPECTREPRO_GOTO_SPLIT_NEXT

            case .up:
                return SPECTREPRO_GOTO_SPLIT_UP

            case .down:
                return SPECTREPRO_GOTO_SPLIT_DOWN

            case .left:
                return SPECTREPRO_GOTO_SPLIT_LEFT

            case .right:
                return SPECTREPRO_GOTO_SPLIT_RIGHT
            }
        }
    }

    /// Enum used for resizing splits. This is the direction the split divider will move.
    enum SplitResizeDirection {
        case up, down, left, right

        static func from(direction: spectrepro_action_resize_split_direction_e) -> Self? {
            switch direction {
            case SPECTREPRO_RESIZE_SPLIT_UP:
                return .up
            case SPECTREPRO_RESIZE_SPLIT_DOWN:
                return .down
            case SPECTREPRO_RESIZE_SPLIT_LEFT:
                return .left
            case SPECTREPRO_RESIZE_SPLIT_RIGHT:
                return .right
            default:
                return nil
            }
        }

        func toNative() -> spectrepro_action_resize_split_direction_e {
            switch self {
            case .up:
                return SPECTREPRO_RESIZE_SPLIT_UP
            case .down:
                return SPECTREPRO_RESIZE_SPLIT_DOWN
            case .left:
                return SPECTREPRO_RESIZE_SPLIT_LEFT
            case .right:
                return SPECTREPRO_RESIZE_SPLIT_RIGHT
            }
        }
    }
}

// MARK: SplitFocusDirection Extensions

extension SpectrePro.SplitFocusDirection {
    /// Convert to a SplitTree.FocusDirection for the given ViewType.
    func toSplitTreeFocusDirection<ViewType>() -> SplitTree<ViewType>.FocusDirection {
        switch self {
        case .previous:
            return .previous

        case .next:
            return .next

        case .up:
            return .spatial(.up)

        case .down:
            return .spatial(.down)

        case .left:
            return .spatial(.left)

        case .right:
            return .spatial(.right)
        }
    }
}

extension SpectrePro {
    /// One representation of clipboard contents. The data is binary-safe;
    /// textual consumers use `string`.
    struct ClipboardContent {
        let mime: String
        let data: Data

        /// The data as text, if it is valid UTF-8.
        var string: String? { String(data: data, encoding: .utf8) }

        static func from(content: spectrepro_clipboard_content_s) -> ClipboardContent? {
            guard let mimePtr = content.mime,
                  let dataPtr = content.data else {
                return nil
            }

            let data: Data = if content.len > 0 {
                Data(bytes: dataPtr, count: content.len)
            } else {
                Data()
            }

            return ClipboardContent(
                mime: String(cString: mimePtr),
                data: data
            )
        }
    }

    /// Enum for the macos-window-buttons config option
    enum MacOSWindowButtons: String {
        case visible
        case hidden
    }

    /// Enum for the macos-titlebar-proxy-icon config option
    enum MacOSTitlebarProxyIcon: String {
        case visible
        case hidden
    }

    /// Enum for auto-update-channel config option
    enum AutoUpdateChannel: String {
        case tip
        case stable
    }
}

// MARK: Surface Notification

extension Notification.Name {
    /// Configuration change. If the object is nil then it is app-wide. Otherwise its surface-specific.
    static let spectreproConfigDidChange = Notification.Name("co.skyones.spectrepro.configDidChange")
    static let SpectreProConfigChangeKey = spectreproConfigDidChange.rawValue

    /// Color change. Object is the surface changing.
    static let spectreproColorDidChange = Notification.Name("co.skyones.spectrepro.spectreproColorDidChange")
    static let SpectreProColorChangeKey = spectreproColorDidChange.rawValue

    /// Goto tab. Has tab index in the userinfo.
    static let spectreproMoveTab = Notification.Name("co.skyones.spectrepro.moveTab")
    static let SpectreProMoveTabKey = spectreproMoveTab.rawValue

    /// Close tab
    static let spectreproCloseTab = Notification.Name("co.skyones.spectrepro.closeTab")

    /// Close other tabs
    static let spectreproCloseOtherTabs = Notification.Name("co.skyones.spectrepro.closeOtherTabs")

    /// Close tabs to the right of the focused tab
    static let spectreproCloseTabsOnTheRight = Notification.Name("co.skyones.spectrepro.closeTabsOnTheRight")

    /// Close window
    static let spectreproCloseWindow = Notification.Name("co.skyones.spectrepro.closeWindow")

    /// Resize the window to a default size.
    static let spectreproResetWindowSize = Notification.Name("co.skyones.spectrepro.resetWindowSize")

    /// Ring the bell
    static let spectreproBellDidRing = Notification.Name("co.skyones.spectrepro.spectreproBellDidRing")

    /// The active selection changed
    static let spectreproSelectionDidChange = Notification.Name("co.skyones.spectrepro.spectreproSelectionDidChange")

    /// Readonly mode changed
    static let spectreproDidChangeReadonly = Notification.Name("co.skyones.spectrepro.didChangeReadonly")
    static let ReadonlyKey = spectreproDidChangeReadonly.rawValue + ".readonly"
    static let spectreproQuickCommandsDidToggle = Notification.Name("co.skyones.spectrepro.quickCommandsDidToggle")
    static let spectreproCommandPaletteDidToggle = Notification.Name("co.skyones.spectrepro.commandPaletteDidToggle")

    /// Toggle maximize of current window
    static let spectreproMaximizeDidToggle = Notification.Name("co.skyones.spectrepro.maximizeDidToggle")

    /// Notification sent when scrollbar updates
    static let spectreproDidUpdateScrollbar = Notification.Name("co.skyones.spectrepro.didUpdateScrollbar")
    static let ScrollbarKey = spectreproDidUpdateScrollbar.rawValue + ".scrollbar"

    /// Focus the search field
    static let spectreproSearchFocus = Notification.Name("co.skyones.spectrepro.searchFocus")
}

// NOTE: I am moving all of these to Notification.Name extensions over time. This
// namespace was the old namespace.
extension SpectrePro.Notification {
    /// Used to pass a configuration along when creating a new tab/window/split.
    static let NewSurfaceConfigKey = "co.skyones.spectrepro.newSurfaceConfig"

    /// Posted when a new split is requested. The sending object will be the surface that had focus. The
    /// userdata has one key "direction" with the direction to split to.
    static let spectreproNewSplit = Notification.Name("co.skyones.spectrepro.newSplit")

    /// Close the calling surface.
    static let spectreproCloseSurface = Notification.Name("co.skyones.spectrepro.closeSurface")

    /// Focus previous/next split. Has a SplitFocusDirection in the userinfo.
    static let spectreproFocusSplit = Notification.Name("co.skyones.spectrepro.focusSplit")
    static let SplitDirectionKey = spectreproFocusSplit.rawValue

    /// Goto tab. Has tab index in the userinfo.
    static let spectreproGotoTab = Notification.Name("co.skyones.spectrepro.gotoTab")
    static let GotoTabKey = spectreproGotoTab.rawValue

    /// New tab. Has base surface config requested in userinfo.
    static let spectreproNewTab = Notification.Name("co.skyones.spectrepro.newTab")

    /// Replace the sending surface with the supplied base configuration.
    static let spectreproReplaceSurface = Notification.Name("co.skyones.spectrepro.replaceSurface")

    /// New window. Has base surface config requested in userinfo.
    static let spectreproNewWindow = Notification.Name("co.skyones.spectrepro.newWindow")

    /// Present terminal. Bring the surface's window to focus without activating the app.
    static let spectreproPresentTerminal = Notification.Name("co.skyones.spectrepro.presentTerminal")

    /// Toggle fullscreen of current window
    static let spectreproToggleFullscreen = Notification.Name("co.skyones.spectrepro.toggleFullscreen")
    static let FullscreenModeKey = spectreproToggleFullscreen.rawValue

    /// Notification sent to toggle split maximize/unmaximize.
    static let didToggleSplitZoom = Notification.Name("co.skyones.spectrepro.didToggleSplitZoom")

    /// Notification
    static let didReceiveInitialWindowFrame = Notification.Name("co.skyones.spectrepro.didReceiveInitialWindowFrame")
    static let FrameKey = "co.skyones.spectrepro.frame"

    /// Notification to render the inspector for a surface
    static let inspectorNeedsDisplay = Notification.Name("co.skyones.spectrepro.inspectorNeedsDisplay")

    /// Notification to show/hide the inspector
    static let didControlInspector = Notification.Name("co.skyones.spectrepro.didControlInspector")

    /// Notification sent to the active split view to resize the split.
    static let didResizeSplit = Notification.Name("co.skyones.spectrepro.didResizeSplit")
    static let ResizeSplitDirectionKey = didResizeSplit.rawValue + ".direction"
    static let ResizeSplitAmountKey = didResizeSplit.rawValue + ".amount"

    /// Notification sent to the split root to equalize split sizes
    static let didEqualizeSplits = Notification.Name("co.skyones.spectrepro.didEqualizeSplits")

    /// Notification that renderer health changed
    static let didUpdateRendererHealth = Notification.Name("co.skyones.spectrepro.didUpdateRendererHealth")

    /// Notifications related to key sequences
    static let didContinueKeySequence = Notification.Name("co.skyones.spectrepro.didContinueKeySequence")
    static let didEndKeySequence = Notification.Name("co.skyones.spectrepro.didEndKeySequence")
    static let KeySequenceKey = didContinueKeySequence.rawValue + ".key"

    /// Notifications related to key tables
    static let didChangeKeyTable = Notification.Name("co.skyones.spectrepro.didChangeKeyTable")
    static let KeyTableKey = didChangeKeyTable.rawValue + ".action"
}

// Make the input enum hashable.
extension spectrepro_input_key_e: @retroactive Hashable {}
