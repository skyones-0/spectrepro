import SwiftUI
import Foundation

struct AboutView: View {
    @Environment(\.openURL) var openURL
    @EnvironmentObject private var viewModel: AboutViewModel

    private let githubURL = URL(string: "https://github.com/skyones-0/spectrepro")
    private let docsURL = URL(string: "https://github.com/skyones-0/spectrepro#readme")

    /// Read the commit from the bundle.
    private var build: String? { Bundle.main.infoDictionary?["CFBundleVersion"] as? String }
    private var commit: String? { Bundle.main.infoDictionary?["SpectreProCommit"] as? String }
    private var version: String? { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String }

    private enum VersionConfig {
        case stable(version: String)
        case tip(commit: String?)
        case other(String)
        case none

        init(version: String?) {
            guard let version else { self = .none; return }
            if version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil {
                self = .stable(version: version)
                return
            }
            if version.range(of: #"^[0-9a-f]{7,40}$"#, options: .regularExpression) != nil {
                self = .tip(commit: version)
                return
            }
            self = .other(version)
        }

        var url: URL? {
            switch self {
            case .stable(let version):
                let slug = version.replacingOccurrences(of: ".", with: "-")
                return URL(string: "https://spectrepro.org/docs/install/release-notes/\(slug)")
            default:
                return nil
            }
        }
    }

    private var versionConfig: VersionConfig { VersionConfig(version: version) }

    private var copyright: String? { Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String }

    private var architecture: String {
        #if arch(arm64)
            "Apple Silicon"
        #elseif arch(x86_64)
            "Intel"
        #else
            "macOS"
        #endif
    }

    private var memoryText: String {
        ByteCountFormatter.string(fromByteCount: Int64(viewModel.residentMemoryBytes), countStyle: .memory)
    }

    private var sessionText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: viewModel.sessionDuration) ?? "0s"
    }

    private var cpuText: String {
        String(format: "%.1f%%", viewModel.processCPUUsage)
    }

    // This creates a background style similar to the Apple "About My Mac" Window
    private struct VisualEffectBackground: NSViewRepresentable {
        let material: NSVisualEffectView.Material
        let blendingMode: NSVisualEffectView.BlendingMode
        let isEmphasized: Bool

        init(material: NSVisualEffectView.Material,
             blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
             isEmphasized: Bool = false) {
            self.material = material
            self.blendingMode = blendingMode
            self.isEmphasized = isEmphasized
        }

        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
            nsView.material = material
            nsView.blendingMode = blendingMode
            nsView.isEmphasized = isEmphasized
        }

        func makeNSView(context: Context) -> NSVisualEffectView {
            let visualEffect = NSVisualEffectView()
            visualEffect.autoresizingMask = [.width, .height]
            return visualEffect
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                spectreproIconImage()
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .padding(10)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Spectre Pro")
                        .font(.title2.weight(.semibold))
                    Text("A native terminal for macOS")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("System status and verified delivery")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 8) {
                GridRow {
                    metadata("Version", versionText)
                    metadata("Arquitectura", architecture)
                }
                GridRow {
                    metadata("Build", build ?? "—")
                    metadata("Commit", commit ?? "—")
                }
            }

            HStack(spacing: 12) {
                RuntimeMetric(title: "Resident memory", value: memoryText, detail: "Current process usage")
                RuntimeMetric(title: "Process CPU", value: cpuText, detail: "Last-second average")
            }

            Text("Monitor active: \(sessionText)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Metrics are measured locally for this process. Comparative benchmarks are published only when reproduced in CI.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let url = docsURL {
                    Button("Documentation") {
                        openURL(url)
                    }
                }
                if let url = githubURL {
                    Button("Repositorio") {
                        openURL(url)
                    }
                }
                if let url = versionConfig.url {
                    Button("Release notes") {
                        openURL(url)
                    }
                }
            }

            if let copyright {
                Text(copyright)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(28)
        .frame(minWidth: 420)
        .background(VisualEffectBackground(material: .underWindowBackground).ignoresSafeArea())
    }

    private var versionText: String {
        switch versionConfig {
        case .stable(let version): version
        case .tip: "Tip Release"
        case .other(let version): version
        case .none: "—"
        }
    }

    private func metadata(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospaced())
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct RuntimeMetric: View {
        let title: String
        let value: String
        let detail: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.monospacedDigit().weight(.medium))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
