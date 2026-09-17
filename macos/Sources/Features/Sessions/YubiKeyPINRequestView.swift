import SwiftUI

struct YubiKeyPINRequestView: View {
    let request: YubiKeyPINRequest
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var pin = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "key.circle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("YubiKey authentication")
                        .font(.headline)
                    Text("PIN required · \(request.retries) tries remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            SecureField("PIN", text: $pin)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(submit)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Continue", action: submit)
                    .buttonStyle(.borderedProminent)
                    .disabled(pin.isEmpty)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.35), lineWidth: 1))
        .onAppear { focused = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("YubiKey PIN authentication")
    }

    private func submit() {
        guard !pin.isEmpty else { return }
        let value = pin
        pin.removeAll(keepingCapacity: false)
        onSubmit(value)
    }
}
