import SwiftUI

struct TimerRingView: View {
    let progress: Double
    let phaseColor: Color
    let lineWidth: CGFloat
    let size: CGFloat
    let content: AnyView?

    init(
        progress: Double,
        phaseColor: Color = .cmPrimary,
        lineWidth: CGFloat = 6,
        size: CGFloat = 200,
        @ViewBuilder content: () -> some View = { EmptyView() }
    ) {
        self.progress = progress
        self.phaseColor = phaseColor
        self.lineWidth = lineWidth
        self.size = size
        self.content = AnyView(content())
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.1)
                .foregroundColor(phaseColor)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(
                    AngularGradient(
                        colors: [.cmPrimary, .cmTeal, phaseColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .conditionalAnimation(.linear(duration: 0.3), value: progress)

            // Center content
            if let content = content {
                content
            }
        }
        .frame(width: size, height: size)
    }
}
