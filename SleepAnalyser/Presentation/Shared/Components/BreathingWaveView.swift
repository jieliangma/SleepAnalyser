import SwiftUI

struct BreathingWaveView: View {
    let breathingRate: Double
    let amplitude: Double
    let isActive: Bool

    @State private var phase: Double = 0

    private var breathCycleDuration: Double {
        breathingRate > 0 ? 60.0 / breathingRate : 4.0
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let midY = h / 2

                drawGlow(context: context, size: size)
                drawWave(context: context, w: w, h: h, midY: midY, isPrimary: false, opacity: 0.15, yScale: 1.3)
                drawWave(context: context, w: w, h: h, midY: midY, isPrimary: false, opacity: 0.3, yScale: 1.0)
                drawWave(context: context, w: w, h: h, midY: midY, isPrimary: true, opacity: 1.0, yScale: 0.7)
                drawBreathIndicator(context: context, size: size)
            }
            .onChange(of: timeline.date) { _, _ in
                phase += (1.0 / 60.0) / breathCycleDuration * .pi * 2
            }
        }
        .opacity(isActive ? 1.0 : 0.3)
        .animation(.easeInOut(duration: 0.5), value: isActive)
    }

    private func drawWave(context: GraphicsContext, w: Double, h: Double, midY: Double, isPrimary: Bool, opacity: Double, yScale: Double) {
        let amp = h * 0.3 * min(1.0, amplitude * 2) * yScale
        let breathPhase = sin(phase) * 0.5 + 0.5
        let dynamicAmp = amp * (0.4 + 0.6 * breathPhase)

        var path = Path()
        let steps = Int(w)
        for i in 0...steps {
            let x = Double(i)
            let t = x / w
            let waveFreq = 3.0 + sin(phase * 0.3) * 0.5
            let envelope = sin(t * .pi)
            let y = midY + sin(t * waveFreq * .pi * 2 + phase * 2) * dynamicAmp * envelope

            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        if isPrimary {
            let gradient = Gradient(colors: [
                Color(hex: "6366F1").opacity(opacity),
                Color(hex: "A855F7").opacity(opacity),
                Color(hex: "6366F1").opacity(opacity)
            ])
            context.stroke(path, with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: w, y: 0)), lineWidth: 2.5)
        } else {
            context.stroke(path, with: .color(Color(hex: "6366F1").opacity(opacity)), lineWidth: 1.5)
        }
    }

    private func drawGlow(context: GraphicsContext, size: CGSize) {
        let breathPhase = sin(phase) * 0.5 + 0.5
        let glowRadius = size.width * 0.3 * (0.3 + 0.7 * breathPhase)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let glowGradient = Gradient(colors: [
            Color(hex: "6366F1").opacity(0.08 * breathPhase),
            Color.clear
        ])
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
            with: .radialGradient(glowGradient, center: center, startRadius: 0, endRadius: glowRadius)
        )
    }

    private func drawBreathIndicator(context: GraphicsContext, size: CGSize) {
        let breathPhase = sin(phase)
        let radius: Double = 4 + 3 * (breathPhase * 0.5 + 0.5)
        let x = size.width / 2 + breathPhase * size.width * 0.15
        let y = size.height / 2 + sin(phase * 2) * size.height * 0.15 * amplitude
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(Color(hex: "818CF8")))
    }
}

struct BreathingStatsOverlay: View {
    let breathingRate: Double
    let breathCount: Int

    var body: some View {
        HStack(spacing: AppSpacing.xl) {
            VStack(spacing: 2) {
                Text(breathingRate > 0 ? String(format: "%.1f", breathingRate) : "—")
                    .font(AppTypography.metricValue).foregroundStyle(AppColors.textPrimary)
                Text("BPM").font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
            VStack(spacing: 2) {
                Text("\(breathCount)")
                    .font(AppTypography.metricValue).foregroundStyle(AppColors.textPrimary)
                Text(L10n.breathCount).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}
