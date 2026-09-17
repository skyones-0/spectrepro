import SwiftUI

@MainActor
private final class SFTPTransferKalmanFilter: ObservableObject {
    @Published private(set) var estimate = 0.5
    @Published private(set) var prediction = 0.5
    @Published private(set) var uncertainty = 0.12

    private var variance = 0.12
    private var velocity = 0.0

    func reset(to value: Double) {
        estimate = min(max(value, 0), 1)
        prediction = estimate
        variance = 0.12
        uncertainty = sqrt(variance)
        velocity = 0
    }

    func update(measurement: Double) {
        let value = min(max(measurement, 0), 1)
        let previousEstimate = estimate
        variance += 0.015
        let gain = variance / (variance + 0.09)
        estimate += gain * (value - estimate)
        variance *= 1 - gain
        velocity = velocity * 0.82 + (estimate - previousEstimate) * 0.18
        prediction = min(max(estimate + velocity * 2.0, 0), 1)
        uncertainty = min(max(sqrt(variance), 0.025), 0.2)
    }
}

struct SFTPTransferGraphView: View {
    let progress: SFTPTransferProgress
    @StateObject private var filter = SFTPTransferKalmanFilter()

    init(progress: SFTPTransferProgress) {
        self.progress = progress
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            Canvas { context, size in
                let activeColor = progress.isUpload ? Color.cyan : Color.green
                let inactiveColor = progress.isUpload ? Color.green : Color.cyan
                let phase = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 1.8) / 1.8

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color.black.opacity(0.28))
                )

                var grid = Path()
                stride(from: 10.0, through: size.width, by: 28.0).forEach { x in
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: 10.0, through: size.height, by: 14.0).forEach { y in
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.06)), lineWidth: 0.5)

                for (index, color) in [inactiveColor, activeColor].enumerated() {
                    var line = Path()
                    let trend = CGFloat(filter.prediction - 0.5)
                    let baseline = size.height * (0.58 + CGFloat(index) * 0.08 - trend * 0.2)
                    line.move(to: CGPoint(x: 0, y: baseline))
                    line.addCurve(
                        to: CGPoint(x: size.width, y: baseline - size.height * 0.08),
                        control1: CGPoint(x: size.width * 0.22, y: baseline - size.height * 0.34),
                        control2: CGPoint(x: size.width * 0.42, y: baseline + size.height * 0.26)
                    )
                    line.addCurve(
                        to: CGPoint(x: size.width, y: baseline - size.height * 0.08),
                        control1: CGPoint(x: size.width * 0.62, y: baseline - size.height * 0.24),
                        control2: CGPoint(x: size.width * 0.82, y: baseline + size.height * 0.16)
                    )
                    context.stroke(line, with: .color(color.opacity(index == 1 ? 0.9 : 0.28)), lineWidth: index == 1 ? 1.5 : 0.8)

                    if index == 1 {
                        let x = size.width * phase
                        let y = baseline - size.height * 0.08 * phase
                        let uncertaintyHeight = size.height * CGFloat(filter.uncertainty)
                        context.fill(
                            Path(CGRect(x: 0, y: y - uncertaintyHeight, width: size.width, height: uncertaintyHeight * 2)),
                            with: .color(activeColor.opacity(0.035))
                        )
                        let point = CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)
                        context.fill(Path(ellipseIn: point), with: .color(activeColor))
                        context.fill(Path(ellipseIn: point.insetBy(dx: -3, dy: -3)), with: .color(activeColor.opacity(0.18)))
                    }
                }
            }
            .frame(height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
        }
        .accessibilityLabel(progress.isUpload ? "Upload activity" : "Download activity")
        .accessibilityValue(progress.detailText)
        .onAppear {
            filter.reset(to: progress.fractionCompleted ?? 0.5)
        }
        .onChange(of: progress) { newProgress in
            filter.update(measurement: newProgress.fractionCompleted ?? filter.estimate)
        }
    }
}
