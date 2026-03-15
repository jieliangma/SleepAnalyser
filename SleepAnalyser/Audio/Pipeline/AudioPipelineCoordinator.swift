import Foundation
import Accelerate

struct PipelineOutput: Sendable {
    let timestamp: Date
    let features: FeatureVector
    let breathingSample: BreathingSample
    let events: [AudioEvent]
    let contextFlags: [String]
}

struct RealtimeAudioFrame: Sendable {
    let rmsLevel: Float
    let noiseDB: Double
    let isBreathPeak: Bool
}

final class AudioPipelineCoordinator: @unchecked Sendable {
    private let preprocessor: AudioPreprocessor
    private let noiseSuppressor: NoiseSuppressor
    private let breathFilter: BandpassBreathFilter
    private let noiseSeparator: NoiseSeparatorBridge
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
    private var realtimeContinuation: AsyncStream<RealtimeAudioFrame>.Continuation?

    private var envelopeHistory: [Float] = []
    private let envelopeWindowSize = 8
    private var prevEnvelopeRising = false
    private var peakCooldown: Int = 0
    private let peakCooldownFrames = 20

    init(preprocessor: AudioPreprocessor = AudioPreprocessor(),
         noiseSuppressor: NoiseSuppressor = NoiseSuppressor(),
         breathFilter: BandpassBreathFilter = BandpassBreathFilter(),
         noiseSeparator: NoiseSeparatorBridge = NoiseSeparatorBridge(),
         featureExtractor: SpectralFeatureExtractor = SpectralFeatureExtractor(),
         breathingEstimator: BreathingRhythmEstimator = BreathingRhythmEstimator(),
         snoreDetector: SnoreDetector = SnoreDetector(),
         disturbanceDetector: DisturbanceDetector = DisturbanceDetector(),
         speechDetector: SpeechTVDetector = SpeechTVDetector(),
         outOfBedDetector: OutOfBedDetector = OutOfBedDetector(),
         metrics: PipelineMetrics = PipelineMetrics()) {
        self.preprocessor = preprocessor
        self.noiseSuppressor = noiseSuppressor
        self.breathFilter = breathFilter
        self.noiseSeparator = noiseSeparator
        self.featureExtractor = featureExtractor
        self.breathingEstimator = breathingEstimator
        self.snoreDetector = snoreDetector
        self.disturbanceDetector = disturbanceDetector
        self.speechDetector = speechDetector
        self.outOfBedDetector = outOfBedDetector
        self.metrics = metrics
    }

    private var roomCalibrated = false

    func configureForRoom(_ room: RoomProfile?, knownNoiseTypes: [NoiseTypeConfig]) {
        if let room {
            noiseSuppressor.loadRoomCalibration(
                noiseFloorSpectrum: room.noiseFloorSpectrum,
                baselineNoiseLevel: room.baselineNoiseLevel,
                micGainFactor: room.micGainFactor
            )
            baselineRMS = Float(pow(10, room.baselineNoiseLevel / 20))
            roomCalibrated = true
        }
    }

    func makeOutputStream() -> AsyncStream<PipelineOutput> {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }

    func makeRealtimeStream() -> AsyncStream<RealtimeAudioFrame> {
        AsyncStream { [weak self] continuation in
            self?.realtimeContinuation = continuation
        }
    }

    func processFrame(_ frame: AudioFrame, sessionId: UUID) {
        let start = CFAbsoluteTimeGetCurrent()

        if epochStartTime == nil { epochStartTime = frame.timestamp }

        let processed = preprocessor.process(frame: frame)
        let suppressed = noiseSuppressor.suppress(processed.samples)

        var rms: Float = 0
        if !suppressed.isEmpty {
            vDSP_rmsqv(suppressed, 1, &rms, vDSP_Length(suppressed.count))
        }

        let isBreathPeak = detectBreathPeak(rms: rms)

        realtimeContinuation?.yield(RealtimeAudioFrame(
            rmsLevel: rms,
            noiseDB: processed.noiseLevel,
            isBreathPeak: isBreathPeak
        ))

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
            if roomCalibrated { contextFlags.append("room_calibrated") }
            if baselineRMS > 0.01 && rms > baselineRMS * 3 { contextFlags.append("above_baseline") }

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

    private func detectBreathPeak(rms: Float) -> Bool {
        envelopeHistory.append(rms)
        if envelopeHistory.count > envelopeWindowSize * 3 {
            envelopeHistory.removeFirst(envelopeHistory.count - envelopeWindowSize * 3)
        }

        if peakCooldown > 0 {
            peakCooldown -= 1
            return false
        }

        guard envelopeHistory.count >= envelopeWindowSize else { return false }

        let recent = Array(envelopeHistory.suffix(envelopeWindowSize))
        let smoothed = recent.reduce(0, +) / Float(recent.count)
        let older = envelopeHistory.count >= envelopeWindowSize * 2
            ? Array(envelopeHistory.suffix(envelopeWindowSize * 2).prefix(envelopeWindowSize))
            : recent
        let prevSmoothed = older.reduce(0, +) / Float(older.count)

        let isRising = smoothed > prevSmoothed
        let isPeak = !isRising && prevEnvelopeRising && smoothed > baselineRMS * 1.5
        prevEnvelopeRising = isRising

        if isPeak {
            peakCooldown = peakCooldownFrames
            return true
        }
        return false
    }

    func reset() {
        epochBuffer = []
        epochStartTime = nil
        lastSnoreEventEnd = nil
        outOfBedDetector.reset()
        metrics.reset()
        envelopeHistory = []
        prevEnvelopeRising = false
        peakCooldown = 0
    }
}
