import SwiftUI

enum AppTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 18, weight: .semibold)
    static let body = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let scoreDisplay = Font.system(size: 56, weight: .bold, design: .rounded)
    static let metricValue = Font.system(size: 20, weight: .semibold, design: .monospaced)
}
