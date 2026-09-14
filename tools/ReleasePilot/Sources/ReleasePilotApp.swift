import SwiftUI

@main
struct ReleasePilotApp: App {
    @StateObject private var coordinator = ReleaseCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .frame(minWidth: 760, idealWidth: 860, minHeight: 540, idealHeight: 620)
        }
        .windowResizability(.contentMinSize)
    }
}
