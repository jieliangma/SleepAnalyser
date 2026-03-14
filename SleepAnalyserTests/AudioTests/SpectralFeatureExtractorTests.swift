import XCTest
@testable import SleepAnalyser

final class SpectralFeatureExtractorTests: XCTestCase {
    let sut = SpectralFeatureExtractor()

    func test_extractFeatures_produces13MFCCCoefficients() {
        let samples = TestAudioFixtures.sineWave(frequency: 440, duration: 0.1)
        let frame = ProcessedFrame(timestamp: Date(), samples: samples, noiseLevel: -30, isVoiceActivity: true)
        let features = sut.extractFeatures(from: frame)
        XCTAssertEqual(features.mfccCoefficients.count, 13)
    }

    func test_extractFeatures_spectralCentroidWithinRange() {
        let samples = TestAudioFixtures.whiteNoise(duration: 0.1)
        let frame = ProcessedFrame(timestamp: Date(), samples: samples, noiseLevel: -30, isVoiceActivity: true)
        let features = sut.extractFeatures(from: frame)
        XCTAssertGreaterThanOrEqual(features.spectralCentroid, 0)
    }

    func test_extractFeatures_rmsMatchesExpected() {
        let amplitude: Float = 0.5
        let samples = [Float](repeating: amplitude, count: 1024)
        let frame = ProcessedFrame(timestamp: Date(), samples: samples, noiseLevel: -30, isVoiceActivity: true)
        let features = sut.extractFeatures(from: frame)
        XCTAssertEqual(features.rmsEnergy, amplitude, accuracy: 0.01)
    }

    func test_extractFeatures_zeroCrossingRate_forSineWave() {
        let samples = TestAudioFixtures.sineWave(frequency: 100, duration: 0.1, sampleRate: 16000)
        let frame = ProcessedFrame(timestamp: Date(), samples: samples, noiseLevel: -30, isVoiceActivity: true)
        let features = sut.extractFeatures(from: frame)
        XCTAssertGreaterThan(features.zeroCrossingRate, 0)
    }

    func test_extractFeatures_emptyInput() {
        let frame = ProcessedFrame(timestamp: Date(), samples: [], noiseLevel: -100, isVoiceActivity: false)
        let features = sut.extractFeatures(from: frame)
        XCTAssertEqual(features.rmsEnergy, 0)
    }
}
