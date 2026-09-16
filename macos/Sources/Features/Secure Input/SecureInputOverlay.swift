import SwiftUI

/// Unified glowing animated gradient background used by SpectrePro overlays
/// (SecureInput lock, Background Tasks platter, and Sidebar buttons).
public struct SpectreProOverlayBackground: View {
    public var cornerRadius: CGFloat = 12
    public var isPermanent: Bool = true
    public var isActive: Bool = true
    public var animatedBorder: Bool = true

    @State private var gradientAngle: Angle = .degrees(0)
    @State private var gradientOpacity: CGFloat = 0.55
    @ObservedObject private var quickCommandsState = QuickCommandsState.shared

    public init(
        cornerRadius: CGFloat = 12,
        isPermanent: Bool = true,
        isActive: Bool = true,
        animatedBorder: Bool = true
    ) {
        self.cornerRadius = cornerRadius
        self.isPermanent = isPermanent
        self.isActive = isActive
        self.animatedBorder = animatedBorder
    }

    private var borderGradient: AngularGradient {
        AngularGradient(
            colors: [.cyan, .blue, .purple, .pink, .orange, .cyan],
            center: .center,
            startAngle: gradientAngle,
            endAngle: gradientAngle + .degrees(360)
        )
    }

    private var borderOpacity: Double {
        guard animatedBorder else { return 0 }
        return isPermanent ? 1 : (isActive ? 1 : 0.22)
    }

    private var usesThinAnimatedBorder: Bool {
        animatedBorder && quickCommandsState.overlayBorderStyle == .thinAnimated
    }

    public var body: some View {
        ZStack {
            if usesThinAnimatedBorder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
            } else {
                if !isPermanent {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(isActive ? 0.3 : 0.8)
                }

                Rectangle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(
                                colors: [.cyan, .blue, .yellow, .blue, .cyan]
                            ),
                            center: .center,
                            angle: gradientAngle
                        )
                    )
                    .blur(radius: 4, opaque: true)
                    .opacity(isPermanent ? gradientOpacity : (isActive ? gradientOpacity : 0))
            }
        }
        .mask(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            Group {
                if usesThinAnimatedBorder {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderGradient, lineWidth: 1)
                            .blur(radius: 3)
                            .opacity(0.35 * borderOpacity)

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(borderGradient, lineWidth: 1)
                            .opacity(borderOpacity)
                    }
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            isPermanent
                                ? Color.white.opacity(0.35)
                                : (isActive ? Color.white.opacity(0.35) : Color.primary.opacity(0.12)),
                            lineWidth: 1
                        )
                }
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 8).repeatForever(autoreverses: false)) {
                gradientAngle = .degrees(360)
            }
            withAnimation(Animation.linear(duration: 8).repeatForever(autoreverses: true)) {
                gradientOpacity = 1.0
            }
        }
    }
}

struct SecureInputOverlay: View {
    @State private var isPopover = false

    var body: some View {
        Image(systemName: "lock.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundColor(.black)
            .frame(width: 35, height: 35)
            .background(SpectreProOverlayBackground(cornerRadius: 12, isPermanent: true))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                isPopover = true
            }
            .backport.pointerStyle(.link)
            .popover(isPresented: $isPopover, arrowEdge: .leading) {
                Text("""
                Secure Input is active. Secure Input is a macOS security feature that
                prevents applications from reading keyboard events. This is enabled
                automatically whenever SpectrePro detects a password prompt in the terminal,
                or at all times if `SpectrePro > Secure Keyboard Entry` is active.
                """)
                .padding(.all)
            }
    }
}

struct SerialExitOverlay: View {
    let onExit: () -> Void

    var body: some View {
        Button(action: onExit) {
            Image(systemName: "figure.walk.departure")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundColor(.black)
                .frame(width: 35, height: 35)
                .background(SpectreProOverlayBackground(cornerRadius: 12, isPermanent: true))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .backport.pointerStyle(.link)
        .help("Disconnect serial session")
        .accessibilityLabel("Disconnect serial session")
        .accessibilityHint("Closes the current serial terminal and releases the device")
    }
}

struct SFTPOpenOverlay: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            Image(systemName: "arrow.up.arrow.down")
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
                .foregroundColor(.black)
                .frame(width: 35, height: 35)
                .background(SpectreProOverlayBackground(cornerRadius: 12, isPermanent: true))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .backport.pointerStyle(.link)
        .help("Open SFTP browser")
        .accessibilityLabel("Open SFTP browser")
        .accessibilityHint("Browse and transfer files over the active SSH connection")
    }
}
