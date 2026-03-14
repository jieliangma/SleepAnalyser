import Foundation
import SwiftUI

enum SleepStageFormatter {
    static func displayName(_ stage: SleepStage) -> String { stage.displayName }
    static func shortName(_ stage: SleepStage) -> String { stage.shortName }
    static func color(_ stage: SleepStage) -> Color { AppColors.stageColor(stage) }
    static func icon(_ stage: SleepStage) -> String { stage.sfSymbolName }

    static func percentString(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}
