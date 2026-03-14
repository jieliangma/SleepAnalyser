import Foundation

struct PipelineOutput: Sendable {
    let timestamp: Date
    let features: FeatureVector
    let breathingSample: BreathingSample
    let events: [AudioEvent]
    let contextFlags: [String]
}

final class AudioPipelineCoordinator: @unchecked Sendable {
    private let preprocessor: AudioPreprocessor
    private let noiseSuppressor: NoiseSuppressor
    private let featureExtractor: SpectralFeatureExtractor
    private let breathingEstimator: BreathingRhythmEstimator
    private let snoreDetector: SnoreDetector
    private let disturbanceDetector: DisturbanceDetector
    private let speechDetector: SpeechTVDetector
    private let outOfBedDetector: OutOfBedDetector
    let metrics: PipelineMetrics

    private let epochDuration: TimeInterval = 30.0
    private var epochBuffer: [Float] = []
    private var epochStartTime: Date?
    private var lastSnoreEventEnd: Date?
    private var baselineRMS: Float = 0.01
    private var continuation: AsyncStream<PipelineOutput>.Continuation?

    init(preprocessor: AudioPreprocessor = AudioPreprocessor(),
         noiseSuppressor: NoiseSuppressor = NoiseSuppressor(),
         featureExtractor: SpectralFeatureExtractor = SpectralFeatureExtractor(),
         breathingEstimator: BreathingRhythmEstimator = BreathingRhythmEstimator(),
         snoreDetector: SnoreDetector = SnoreDetector(),
         disturbanceDetector: DisturbanceDetector = DisturbanceDetector(),
         speechDetector: SpeechTVDetector = SpeechTVDetector(),
         outOfBedDetector: OutOfBedDetector = OutOfBedDetector(),
         metrics: PipelineMetrics = PipelineMetrics()) {
        self.preprocessor = preprocessor
        self.noiseSuppressor = noiseSuppressor
        self.featureExtractor = featureExtractor
        self.breathingEstimator = breathingEstimator
        self.snoreDetector = snoreDetector
        self.disturbanceDetector = disturbanceDetector
        self.speechDetector = speechDetector
        self.outOfBedDetector = outOfBedDetector
        self.metrics = metrics
    }

    func makeOutputStream() -> AsyncStream<PipelineOutput> {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }

    func processFrame(_ frame: AudioFrame, sessionId: UUID) {
        let start = CFAbsoluteTimeGetCurrent()

        if epochStartTime == nil { epochStartTime = frame.timestamp }

        let processed = preprocessor.process(frame: frame)
        let suppressed = noiseSuppressor.suppress(processed.samples)

        let processedForFeatures = ProcessedFrame(
            timestamp: processed.timestamp,
            samples: suppressed,
            noiseLevel: processed.noiseLevel,
            isVoiceActivity: processed.isVoiceActivity
        )

        epochBuffer.append(contentsOf: suppressed)

        var events: [AudioEvent] = []

        if let snoreEvent = snoreDetector.detect(
            samples: suppressed, sampleRate: frame.sampleRate,
            sessionId: sessionId, timestamp: frame.timestamp, lastEventEnd: lastSnoreEventEnd
        ) {
            events.append(snoreEvent)
            lastSnoreEventEnd = snoreEvent.endAt
        }

        if let distEvent = disturbanceDetector.detect(
            samples: suppressed, sampleRate: frame.sampleRate,
            sessionId: sessionId, timestamp: frame.timestamp, baselineRMS: baselineRMS
        ) {
            events.append(distEvent)
        }

        if let speechEvent = speechDetector.detect(
            samples: suppressed, sampleRate: frame.sampleRate,
            sessionId: sessionId, timestamp: frame.timestamp
        ) {
            events.append(speechEvent)
        }

        if let bedEvent = outOfBedDetector.update(
            samples: suppressed, sessionId: sessionId, timestamp: frame.timestamp
        ) {
            events.append(bedEvent)
        }

        let epochSamples = Int(epochDuration * frame.sampleRate)
        if epochBuffer.count >= epochSamples, let epochStart = epochStartTime {
            let epochData = Array(epochBuffer.prefix(epochSamples))
            epochBuffer = Array(epochBuffer.dropFirst(epochSamples))

            let features = featureExtractor.extractFeatures(from: processedForFeatures)
            let breathing = breathingEstimator.estimate(from: epochData)

            var contextFlags: [String] = []
            if !events.isEmpty { contextFlags.append("has_events") }
            if processed.noiseLevel > -20 { contextFlags.append("high_noise") }

            let output = PipelineOutput(
                timestamp: epochStart,
                features: features,
                breathingSample: breathing,
                events: events,
                contextFlags: contextFlags
            )
            continuation?.yield(output)
            metrics.recordEpoch()
            epochStartTime = Date()
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        metrics.recordLatency(elapsed)
    }

    func reset() {
        epochBuffer = []
        epochStartTime = nil
        lastSnoreEventEnd = nil
        outOfBedDetector.reset()
        metrics.reset()
    }
}
