import Foundation

enum ReleaseRules {
    static func nextPatchVersion(after version: String) -> String? {
        guard let components = components(of: version) else { return nil }
        return "\(components[0]).\(components[1]).\(components[2] + 1)"
    }

    static func isVersion(_ lhs: String, greaterThan rhs: String) -> Bool {
        guard let left = components(of: lhs), let right = components(of: rhs) else { return false }
        return left.lexicographicallyPrecedes(right) == false && left != right
    }

    static func manifestVersion(in contents: String) -> String? {
        guard let match = contents.range(of: #"\.version\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)""#, options: .regularExpression) else {
            return nil
        }
        return contents[match].split(separator: "\"").dropFirst().first.map(String.init)
    }

    static func validate(version: String, manifest: String, latestTag: String) throws {
        guard components(of: version) != nil else { throw ReleasePilotError.invalidVersion }
        guard manifestVersion(in: manifest) == version else {
            let declared = manifestVersion(in: manifest) ?? "an invalid version"
            throw ReleasePilotError.commandFailed("build.zig.zon declares \(declared), not \(version). Update the project version before publishing.")
        }
        if latestTag.hasPrefix("v"), !isVersion(version, greaterThan: String(latestTag.dropFirst())) {
            throw ReleasePilotError.commandFailed("\(version) must be greater than the latest tag, \(latestTag).")
        }
    }

    static func checksState(for runs: [CheckRun]) -> String {
        if runs.contains(where: { $0.status != "completed" }) { return "Waiting for checks" }
        if runs.contains(where: { $0.conclusion != "success" && $0.conclusion != "skipped" }) { return "Checks failed" }
        return "All checks passed"
    }

    private static func components(of version: String) -> [Int]? {
        guard version.range(of: "^[0-9]+\\.[0-9]+\\.[0-9]+$", options: .regularExpression) != nil else { return nil }
        return version.split(separator: ".").compactMap { Int($0) }
    }
}
