import Foundation
import Accelerate
import AVFoundation

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
    private let breathFilter: AdaptiveBreathFilter
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
    private let peakCooldownFrames = 500

    init(preprocessor: AudioPreprocessor = AudioPreprocessor(),
         noiseSuppressor: NoiseSuppressor = NoiseSuppressor(),
         breathFilter: AdaptiveBreathFilter = AdaptiveBreathFilter(),
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

            if let specData = room.noiseFloorSpectrum {
                let spectrum = specData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
                noiseSeparator.loadRoomNoiseFloor(spectrum)
            }
        }

        noiseSeparator.clearTemplates()
        for config in knownNoiseTypes {
            for clipURL in config.soundClipURLs {
                if let spectrum = extractSpectrumFromClip(clipURL) {
                    let cType = NoiseTypeLabel(rawValue: config.name)?.toCType ?? NS_NOISE_UNKNOWN
                    noiseSeparator.addNoiseTemplate(type: cType, spectrum: spectrum)
                }
            }
        }
    }

    private func extractSpectrumFromClip(_ url: URL) -> [Float]? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let frameCount = AVAudioFrameCount(min(file.length, 16384))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount),
              let _ = try? file.read(into: buffer, frameCount: frameCount),
              let channelData = buffer.floatChannelData else { return nil }
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        let bands = noiseSeparator.computeBandEnergy(samples: samples)
        return [bands.subBass, bands.bass, bands.lowMid, bands.mid, bands.highMid, bands.presence, bands.brilliance]
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

        noiseSeparator.updateNoiseFloor(samples: suppressed)
        let separation = noiseSeparator.templateEnhancedSeparate(input: suppressed)
        let foreground = separation.foreground

        var rms: Float = 0
        if !foreground.isEmpty {
            vDSP_rmsqv(foreground, 1, &rms, vDSP_Length(foreground.count))
        }

        let breathFiltered = breathFilter.filter(foreground)
        var breathRMS: Float = 0
        if !breathFiltered.isEmpty {
            vDSP_rmsqv(breathFiltered, 1, &breathRMS, vDSP_Length(breathFiltered.count))
        }
        let isBreathPeak = detectBreathPeak(rms: breathRMS)

        realtimeContinuation?.yield(RealtimeAudioFrame(
            rmsLevel: rms,
            noiseDB: processed.noiseLevel,
            isBreathPeak: isBreathPeak
        ))

        let processedForFeatures = ProcessedFrame(
            timestamp: processed.timestamp,
            samples: foreground,
            noiseLevel: processed.noiseLevel,
            isVoiceActivity: processed.isVoiceActivity
        )

        epochBuffer.append(contentsOf: foreground)

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

            let breathData = breathFilter.filter(epochData)
            let features = featureExtractor.extractFeatures(from: processedForFeatures)
            let breathing = breathingEstimator.estimate(from: breathData)

            if breathing.isValid {
                breathFilter.adapt(detectedBPM: breathing.breathsPerMinute)
            }

            let noiseLayers = noiseSeparator.decomposeMultiLayer(samples: suppressed)
            let noiseBands = noiseSeparator.computeBandEnergy(samples: suppressed)
            var contextFlags: [String] = []
            if !events.isEmpty { contextFlags.append("has_events") }
            if processed.noiseLevel > -20 { contextFlags.append("high_noise") }
            if roomCalibrated { contextFlags.append("room_calibrated") }
            if baselineRMS > 0.01 && rms > baselineRMS * 3 { contextFlags.append("above_baseline") }
            for layer in noiseLayers {
                contextFlags.append("noise_\(layer.type.rawValue)")
            }
            contextFlags.append("noise_rms_\(String(format: "%.4f", noiseBands.totalRMS))")
            contextFlags.append("noise_bass_\(String(format: "%.4f", noiseBands.bass))")
            contextFlags.append("noise_mid_\(String(format: "%.4f", noiseBands.mid))")

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
