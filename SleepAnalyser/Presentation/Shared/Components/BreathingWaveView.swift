import SwiftUI

struct BreathingWaveView: View {
    let breathingRate: Double
    let amplitude: Double
    let isActive: Bool

    @State private var phase: Double = 0
    @State private var peakFlash: Double = 0

    private var breathCycleDuration: Double {
        breathingRate > 0 ? 60.0 / breathingRate : 4.0
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let midY = h / 2
                let amp = min(1.0, amplitude * 10)

                drawGlow(context: context, size: size, amp: amp)
                drawWave(context: context, w: w, h: h, midY: midY, amp: amp, opacity: 0.1, yScale: 1.4, lineWidth: 1.0)
                drawWave(context: context, w: w, h: h, midY: midY, amp: amp, opacity: 0.25, yScale: 1.0, lineWidth: 1.5)
                drawWave(context: context, w: w, h: h, midY: midY, amp: amp, opacity: 0.9, yScale: 0.65, lineWidth: 2.5)

                if peakFlash > 0 {
                    drawPeakRing(context: context, size: size)
                }
            }
            .onChange(of: timeline.date) { _, _ in
                phase += (1.0 / 60.0) / breathCycleDuration * .pi * 2
                if peakFlash > 0 { peakFlash = max(0, peakFlash - 0.03) }
            }
        }
        .opacity(isActive ? 1.0 : 0.3)
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }

    func onBreathDetected() -> BreathingWaveView {
        var copy = self
        copy.peakFlash = 1.0
        return copy
    }

    private func drawWave(context: GraphicsContext, w: Double, h: Double, midY: Double, amp: Double, opacity: Double, yScale: Double, lineWidth: Double) {
        let baseAmp = h * 0.28 * yScale
        let liveAmp = baseAmp * (0.15 + 0.85 * amp)

        var path = Path()
        let steps = Int(w)
        for i in 0...steps {
            let x = Double(i)
            let t = x / w
            let envelope = sin(t * .pi)
            let waveY = sin(t * .pi * 6 + phase * 2)
            let breathMod = sin(phase) * 0.3 + 0.7
            let y = midY + waveY * liveAmp * envelope * breathMod

            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        let grad = Gradient(colors: [
            Color(hex: "6366F1").opacity(opacity),
            Color(hex: "A855F7").opacity(opacity * 0.8),
            Color(hex: "818CF8").opacity(opacity)
        ])
        context.stroke(path, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: w, y: 0)), lineWidth: lineWidth)
    }

    private func drawGlow(context: GraphicsContext, size: CGSize, amp: Double) {
        let breathPhase = sin(phase) * 0.5 + 0.5
        let r = size.width * 0.25 * (0.3 + 0.7 * breathPhase) * (0.3 + 0.7 * amp)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let grad = Gradient(colors: [
            Color(hex: "6366F1").opacity(0.12 * amp),
            Color.clear
        ])
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
            with: .radialGradient(grad, center: center, startRadius: 0, endRadius: r)
        )
    }

    private func drawPeakRing(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = 30 + (1 - peakFlash) * 40
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(Color(hex: "A855F7").opacity(peakFlash * 0.6)),
            lineWidth: 2
        )
    }
}

struct BreathingStatsOverlay: View {
    let breathingRate: Double
    let breathCount: Int
    let amplitude: Double

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xl) {
                statBlock(
                    value: breathingRate > 0 ? String(format: "%.1f", breathingRate) : "—",
                    label: "BPM",
                    color: AppColors.primaryLight
                )
                statBlock(
                    value: "\(breathCount)",
                    label: L10n.breathCount,
                    color: Color(hex: "A855F7")
                )
            }

            amplitudeBar
        }
    }

    private func statBlock(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppTypography.metricValue)
                .foregroundStyle(AppColors.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: value)
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    private var amplitudeBar: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { i in
                let threshold = Double(i) / 20.0
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(index: i, active: amplitude * 5 > threshold))
                    .frame(width: 6, height: amplitude * 5 > threshold ? 16 : 6)
                    .animation(.easeOut(duration: 0.08), value: amplitude)
            }
        }
    }

    private func barColor(index: Int, active: Bool) -> Color {
        guard active else { return AppColors.surfaceLight }
        let t = Double(index) / 20.0
        if t < 0.5 { return AppColors.primary.opacity(0.5 + t) }
        if t < 0.8 { return AppColors.primaryLight }
        return Color(hex: "A855F7")
    }
}
