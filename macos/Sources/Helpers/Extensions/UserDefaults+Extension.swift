import Foundation

extension UserDefaults {
    static var spectreproSuite: String? {
        #if DEBUG
        ProcessInfo.processInfo.environment["SPECTREPRO_USER_DEFAULTS_SUITE"]
        #else
        nil
        #endif
    }

    static var spectrepro: UserDefaults {
        spectreproSuite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }
}
