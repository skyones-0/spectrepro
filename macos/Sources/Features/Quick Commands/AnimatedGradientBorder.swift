import SwiftUI

struct AnimatedGradientBorder: ViewModifier {
    var cornerRadius: CGFloat = 12
    var lineWidth: CGFloat = 1
    var glowRadius: CGFloat = 6
    var duration: Double = 8

    @State private var angle: Double = 0

    private var gradient: AngularGradient {
        AngularGradient(
            colors: [
                .cyan.opacity(0.9),
                .blue.opacity(0.8),
                .purple.opacity(0.85),
                .pink.opacity(0.75),
                .orange.opacity(0.8),
                .cyan.opacity(0.9)
            ],
            center: .center,
            startAngle: .degrees(angle),
            endAngle: .degrees(angle + 360)
        )
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(gradient, lineWidth: lineWidth)
                        .blur(radius: glowRadius)
                        .opacity(0.35)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradient, lineWidth: lineWidth)
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                angle = 0
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
            .onDisappear {
                angle = 0
            }
    }
}

extension View {
    func animatedGradientBorder(
        cornerRadius: CGFloat = 12,
        lineWidth: CGFloat = 1,
        glowRadius: CGFloat = 6,
        duration: Double = 8
    ) -> some View {
        modifier(
            AnimatedGradientBorder(
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                glowRadius: glowRadius,
                duration: duration
            )
        )
    }
}
