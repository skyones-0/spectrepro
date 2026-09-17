import SwiftUI

struct YubiKeyDetectedOverlay: View {
    let state: YubiKeyAuthenticationState
    @State private var isHovered = false

    private var tint: Color {
        switch state {
        case .waitingForPIN: return .orange
        case .waitingForTouch: return .yellow
        case .authenticated: return .green
        case .failed: return .red
        default: return .cyan
        }
    }

    var body: some View {
        Image(systemName: "key.circle.fill")
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 35, height: 35)
            .background(SpectreProOverlayBackground(cornerRadius: 12, isPermanent: true, isActive: isHovered))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onHover { isHovered = $0 }
            .help("YubiKey PIV detected")
            .accessibilityLabel("YubiKey PIV detected")
    }
}
