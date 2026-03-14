import XCTest
@testable import SleepAnalyser

final class ConfidenceSmootherTests: XCTestCase {
    let sut = ConfidenceSmoother()

    func test_smoothingReducesJitter() {
        let val1 = sut.smooth(rawConfidence: 0.8, previousSmoothed: 0.5, noiseLevel: -40, disturbanceActive: false)
        let val2 = sut.smooth(rawConfidence: 0.3, previousSmoothed: val1, noiseLevel: -40, disturbanceActive: false)
        XCTAssertGreaterThan(val2, 0.3)
    }

    func test_highNoiseReducesConfidence() {
        let clean = sut.smooth(rawConfidence: 0.8, previousSmoothed: 0.5, noiseLevel: -40, disturbanceActive: false)
        let noisy = sut.smooth(rawConfidence: 0.8, previousSmoothed: 0.5, noiseLevel: -10, disturbanceActive: false)
        XCTAssertLessThan(noisy, clean)
    }

    func test_disturbanceReducesConfidence() {
        let normal = sut.smooth(rawConfidence: 0.8, previousSmoothed: 0.5, noiseLevel: -40, disturbanceActive: false)
        let disturbed = sut.smooth(rawConfidence: 0.8, previousSmoothed: 0.5, noiseLevel: -40, disturbanceActive: true)
        XCTAssertLessThan(disturbed, normal)
    }

    func test_outputClamped() {
        let result = sut.smooth(rawConfidence: 2.0, previousSmoothed: 0.5, noiseLevel: -40, disturbanceActive: false)
        XCTAssertLessThanOrEqual(result, 1.0)
        XCTAssertGreaterThanOrEqual(result, 0.0)
    }
}
