import Foundation

struct SleepScore: Codable, Sendable {
    let overall: Double
    let durationScore: Double
    let efficiencyScore: Double
    let stageBalanceScore: Double
    let disturbanceScore: Double

    var grade: String {
        switch overall {
        case 90...100: return "A"
        case 80..<90:  return "B"
        case 70..<80:  return "C"
        case 60..<70:  return "D"
        default:       return "F"
        }
    }

    var gradeColorHex: String {
        switch grade {
        case "A": return "22C55E"
        case "B": return "84CC16"
        case "C": return "EAB308"
        case "D": return "F59E0B"
        default:  return "EF4444"
        }
    }

    static let perfect = SleepScore(
        overall: 100, durationScore: 100,
        efficiencyScore: 100, stageBalanceScore: 100, disturbanceScore: 100
    )

    static let zero = SleepScore(
        overall: 0, durationScore: 0,
        efficiencyScore: 0, stageBalanceScore: 0, disturbanceScore: 0
    )
}
