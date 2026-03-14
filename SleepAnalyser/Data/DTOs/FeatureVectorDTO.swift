import Foundation

struct FeatureVectorDTO: Codable, Sendable {
    let timestamp: Date
    let mfcc: [Float]
    let centroid: Float
    let rolloff: Float
    let flatness: Float
    let zcr: Float
    let rms: Float
    let breathPeriodicity: Float
    let breathVariability: Float

    init(from feature: FeatureVector) {
        self.timestamp = feature.timestamp
        self.mfcc = feature.mfccCoefficients
        self.centroid = feature.spectralCentroid
        self.rolloff = feature.spectralRolloff
        self.flatness = feature.spectralFlatness
        self.zcr = feature.zeroCrossingRate
        self.rms = feature.rmsEnergy
        self.breathPeriodicity = feature.breathingPeriodicity
        self.breathVariability = feature.breathIntervalVariability
    }

    func toDomain() -> FeatureVector {
        FeatureVector(
            timestamp: timestamp, mfccCoefficients: mfcc,
            spectralCentroid: centroid, spectralRolloff: rolloff,
            spectralFlatness: flatness, zeroCrossingRate: zcr,
            rmsEnergy: rms, breathingPeriodicity: breathPeriodicity,
            breathIntervalVariability: breathVariability
        )
    }
}
