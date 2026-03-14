import Foundation

enum AppConstants {
    enum Audio {
        static let sampleRate: Double = 16000.0
        static let frameSize: Int = 1024
        static let hopSize: Int = 512
        static let epochDuration: TimeInterval = 30.0
    }

    enum ML {
        static let minConfidence: Double = 0.3
        static let smoothingWindow: Int = 5
    }

    enum Sleep {
        static let minSessionDuration: TimeInterval = 1800
        static let maxSessionDuration: TimeInterval = 50400
        static let targetSleepDuration: TimeInterval = 28800
        static let sleepCycleDuration: TimeInterval = 5400
    }

    enum UI {
        static let minWindowWidth: CGFloat = 900
        static let minWindowHeight: CGFloat = 650
        static let menuBarPopoverWidth: CGFloat = 320
    }

    enum Breathing {
        static let minRate: Double = 6.0
        static let maxRate: Double = 30.0
        static let normalRange: ClosedRange<Double> = 12.0...20.0
    }
}
