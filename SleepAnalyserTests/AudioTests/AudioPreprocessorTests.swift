import XCTest
@testable import SleepAnalyser

final class AudioPreprocessorTests: XCTestCase {
    let sut = AudioPreprocessor()

    func test_process_removeDCOffset_outputHasNearZeroMean() {
        var samples = [Float](repeating: 0.5, count: 1024)
        samples = samples.map { $0 + Float.random(in: -0.1...0.1) }
        let frame = AudioFrame(timestamp: Date(), samples: samples, sampleRate: 16000, channelCount: 1)
        let result = sut.process(frame: frame)
        let mean = result.samples.reduce(0, +) / Float(result.samples.count)
        XCTAssertLessThan(abs(mean), 0.1)
    }

    func test_process_silenceInput_returnsLowNoiseLevel() {
        let frame = AudioFrame(timestamp: Date(), samples: [Float](repeating: 0, count: 1024), sampleRate: 16000, channelCount: 1)
        let result = sut.process(frame: frame)
        XCTAssertLessThan(result.noiseLevel, -50)
    }

    func test_process_emptyInput() {
        let frame = AudioFrame(timestamp: Date(), samples: [], sampleRate: 16000, channelCount: 1)
        let result = sut.process(frame: frame)
        XCTAssertTrue(result.samples.isEmpty)
    }

    func test_process_sineWave_preservesSignal() {
        let samples = TestAudioFixtures.sineWave(frequency: 440, duration: 0.064)
        let frame = AudioFrame(timestamp: Date(), samples: samples, sampleRate: 16000, channelCount: 1)
        let result = sut.process(frame: frame)
        XCTAssertEqual(result.samples.count, samples.count)
        XCTAssertTrue(result.isVoiceActivity)
    }
}
