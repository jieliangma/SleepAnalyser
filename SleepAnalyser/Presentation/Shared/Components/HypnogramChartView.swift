import SwiftUI
import Charts

struct HypnogramChartView: View {
    let epochs: [SleepEpoch]

    var body: some View {
        Chart(epochs, id: \.id) { epoch in
            LineMark(
                x: .value("Time", epoch.timestamp),
                y: .value("Stage", epoch.predictedStage.order)
            )
            .foregroundStyle(AppColors.stageColor(epoch.predictedStage))
            .interpolationMethod(.stepEnd)

            AreaMark(
                x: .value("Time", epoch.timestamp),
                y: .value("Stage", epoch.predictedStage.order)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [AppColors.stageColor(epoch.predictedStage).opacity(0.3), .clear],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.stepEnd)
        }
        .chartYScale(domain: 0...5)
        .chartYAxis {
            AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text(stageName(for: intVal))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(AppColors.surfaceLight)
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(height: 200)
    }

    private func stageName(for order: Int) -> String {
        switch order {
        case 5: return "Awake"
        case 4: return "REM"
        case 3: return "N1"
        case 2: return "N2"
        case 1: return "Deep"
        default: return ""
        }
    }
}
