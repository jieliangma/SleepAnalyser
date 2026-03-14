import Foundation

struct FeatureVector: Sendable {
    let timestamp: Date
    let mfccCoefficients: [Float]
    let spectralCentroid: Float
    let spectralRolloff: Float
    let spectralFlatness: Float
    let zeroCrossingRate: Float
    let rmsEnergy: Float
    let breathingPeriodicity: Float
    let breathIntervalVariability: Float

    static let featureCount = 20

    func toArray() -> [Float] {
        var result = mfccCoefficients
        result.append(contentsOf: [
            spectralCentroid, spectralRolloff, spectralFlatness,
            zeroCrossingRate, rmsEnergy,
            breathingPeriodicity, breathIntervalVariability
        ])
        return result
    }
}
