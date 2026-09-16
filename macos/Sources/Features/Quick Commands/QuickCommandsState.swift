import SwiftUI
import Combine

public enum SidebarTab: String, CaseIterable, Identifiable {
    case commands = "Commands"
    case serial = "Serial"
    case sessions = "Sessions"
    case tasks = "Tasks"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .commands: return "apple.terminal"
        case .serial: return "cable.connector"
        case .sessions: return "server.rack"
        case .tasks: return "list.bullet.rectangle"
        }
    }

    public var title: String {
        switch self {
        case .commands: return "Commands"
        case .serial: return "Serial"
        case .sessions: return "Sessions"
        case .tasks: return "Tasks"
        }
    }

    public var longTitle: String {
        switch self {
        case .commands: return "Quick Commands"
        case .serial: return "Serial Connection"
        case .sessions: return "Session Manager"
        case .tasks: return "Background Tasks"
        }
    }
}

enum OverlayBorderStyle: String, CaseIterable, Identifiable {
    case current
    case thinAnimated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .current: return "Current"
        case .thinAnimated: return "Thin animated"
        }
    }
}

/// Shared state for Quick Commands sidebar across all windows and tabs.
/// Ensures that sidebar visibility, width, filter, and active group
/// are globally unified and target the currently active terminal session.
@MainActor
final class QuickCommandsState: ObservableObject {
    static let shared = QuickCommandsState()

    private let userDefaults = UserDefaults.standard
    private let isShowingKey = "co.skyones.spectrepro.quickCommandsIsShowing"
    private let widthKey = "co.skyones.spectrepro.quickCommandsWidth"

    @Published var isShowing: Bool {
        didSet {
            userDefaults.set(isShowing, forKey: isShowingKey)
        }
    }

    @Published var width: CGFloat {
        didSet {
            userDefaults.set(width, forKey: widthKey)
        }
    }

    @Published var activeTab: SidebarTab = .commands
    @Published var selectedSerialDevicePath: String? = nil
    @Published var searchText: String = ""
    @Published var selectedGroup: String? = nil
    @Published var isBroadcast: Bool = false
    @Published var selectedIndex: Int? = nil
    @Published var isAnimatedBorderEnabled: Bool {
        didSet {
            userDefaults.set(isAnimatedBorderEnabled, forKey: "co.skyones.spectrepro.animatedSidebarBorder")
        }
    }
    @Published var overlayBorderStyle: OverlayBorderStyle {
        didSet {
            userDefaults.set(overlayBorderStyle.rawValue, forKey: "co.skyones.spectrepro.overlayBorderStyle")
        }
    }

    private init() {
        self.isShowing = userDefaults.bool(forKey: isShowingKey)
        let savedWidth = CGFloat(userDefaults.double(forKey: widthKey))
        self.width = savedWidth > 150 ? savedWidth : 320
        self.isAnimatedBorderEnabled = userDefaults.object(forKey: "co.skyones.spectrepro.animatedSidebarBorder") as? Bool ?? true
        self.overlayBorderStyle = OverlayBorderStyle(
            rawValue: userDefaults.string(forKey: "co.skyones.spectrepro.overlayBorderStyle") ?? "current"
        ) ?? .current
    }

    func toggle() {
        isShowing.toggle()
    }

    func showTab(_ tab: SidebarTab) {
        self.activeTab = tab
        self.isShowing = true
    }
}
