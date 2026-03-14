import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

enum AppColors {
    static let background = Color(hex: "0F172A")
    static let surface = Color(hex: "1E293B")
    static let surfaceLight = Color(hex: "334155")
    static let primary = Color(hex: "6366F1")
    static let primaryLight = Color(hex: "818CF8")
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "94A3B8")
    static let textTertiary = Color(hex: "64748B")

    static func stageColor(_ stage: SleepStage) -> Color {
        Color(hex: stage.colorHex)
    }

    static func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return success
        case 60..<80:  return warning
        default:       return error
        }
    }

    static func confidenceColor(_ level: ConfidenceLevel) -> Color {
        Color(hex: level.colorHex)
    }
}
