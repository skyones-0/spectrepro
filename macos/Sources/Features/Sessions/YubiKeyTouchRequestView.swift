import SwiftUI

struct YubiKeyTouchRequestView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.circle.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.yellow)
                .scaleEffect(isAnimating ? 1.08 : 1.0)
                .opacity(isAnimating ? 0.72 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)

            VStack(alignment: .leading, spacing: 2) {
                Text("Touch your YubiKey")
                    .font(.headline)
                Text("Touch the key to approve this connection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            ProgressView()
                .controlSize(.small)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
        .onAppear { isAnimating = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Touch your YubiKey to approve this connection")
    }
}
