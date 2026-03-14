import SwiftUI
import Charts

struct HypnogramChartView: View {
    let epochs: [SleepEpoch]

    var body: some View {
        Chart(epochs, id: \.id) { epoch in
            LineMark(x: .value(L10n.chartTime, epoch.timestamp), y: .value(L10n.chartStage, epoch.predictedStage.order))
                .foregroundStyle(AppColors.stageColor(epoch.predictedStage))
                .interpolationMethod(.stepEnd)
            AreaMark(x: .value(L10n.chartTime, epoch.timestamp), y: .value(L10n.chartStage, epoch.predictedStage.order))
                .foregroundStyle(LinearGradient(colors: [AppColors.stageColor(epoch.predictedStage).opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.stepEnd)
        }
        .chartYScale(domain: 0...5)
        .chartYAxis {
            AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text(stageLabel(for: intVal)).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(AppColors.surfaceLight)
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated))).foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(height: 200)
    }

    private func stageLabel(for order: Int) -> String {
        switch order {
        case 5: return L10n.stageShortAwake
        case 4: return L10n.stageShortREM
        case 3: return L10n.stageShortN1
        case 2: return L10n.stageShortN2
        case 1: return L10n.stageShortDeep
        default: return ""
        }
    }
}
