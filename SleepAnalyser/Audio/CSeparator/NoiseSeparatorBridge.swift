import Foundation
import AVFoundation

final class NoiseSeparatorBridge: @unchecked Sendable {
    private var state = ns_state_t()

    init(fftSize: Int32 = 1024, sampleRate: Float = 16000) {
        ns_init(&state, fftSize, sampleRate)
    }

    func reset() { ns_reset(&state) }

    func loadRoomNoiseFloor(_ spectrum: [Float]) {
        spectrum.withUnsafeBufferPointer { buf in
            ns_load_room_noise_floor(&state, buf.baseAddress, Int32(buf.count))
        }
    }

    func addNoiseTemplate(type: ns_noise_type_t, spectrum: [Float]) {
        spectrum.withUnsafeBufferPointer { buf in
            ns_add_noise_template(&state, type, buf.baseAddress, Int32(buf.count))
        }
    }

    func clearTemplates() { ns_clear_templates(&state) }

    func updateNoiseFloor(samples: [Float]) {
        samples.withUnsafeBufferPointer { buf in
            ns_update_noise_floor(&state, buf.baseAddress, Int32(buf.count))
        }
    }

    func templateEnhancedSeparate(input: [Float]) -> SeparationResult {
        var fg = [Float](repeating: 0, count: input.count)
        var bg = [Float](repeating: 0, count: input.count)
        input.withUnsafeBufferPointer { inBuf in
            fg.withUnsafeMutableBufferPointer { fgBuf in
                bg.withUnsafeMutableBufferPointer { bgBuf in
                    ns_template_enhanced_separate(&state, inBuf.baseAddress, Int32(inBuf.count),
                                                  fgBuf.baseAddress, bgBuf.baseAddress)
                }
            }
        }
        return SeparationResult(foreground: fg, background: bg)
    }

    struct SeparationResult {
        let foreground: [Float]
        let background: [Float]
    }

    func separate(input: [Float]) -> SeparationResult {
        var fg = [Float](repeating: 0, count: input.count)
        var bg = [Float](repeating: 0, count: input.count)
        input.withUnsafeBufferPointer { inBuf in
            fg.withUnsafeMutableBufferPointer { fgBuf in
                bg.withUnsafeMutableBufferPointer { bgBuf in
                    ns_separate_noise(&state, inBuf.baseAddress, Int32(inBuf.count),
                                      fgBuf.baseAddress, bgBuf.baseAddress)
                }
            }
        }
        return SeparationResult(foreground: fg, background: bg)
    }

    func computeBandEnergy(samples: [Float], sampleRate: Float = 16000) -> NoiseBandEnergy {
        let bands = samples.withUnsafeBufferPointer { buf in
            ns_compute_band_energy(buf.baseAddress, Int32(buf.count), sampleRate)
        }
        return NoiseBandEnergy(
            subBass: bands.sub_bass, bass: bands.bass, lowMid: bands.low_mid,
            mid: bands.mid, highMid: bands.high_mid, presence: bands.presence,
            brilliance: bands.brilliance, totalRMS: bands.total_rms
        )
    }

    func classifyNoise(samples: [Float], sampleRate: Float = 16000) -> (type: NoiseTypeLabel, confidence: Float) {
        let bands = samples.withUnsafeBufferPointer { buf in
            ns_compute_band_energy(buf.baseAddress, Int32(buf.count), sampleRate)
        }
        let crest = samples.withUnsafeBufferPointer { buf in
            ns_compute_crest_factor(buf.baseAddress, Int32(buf.count))
        }
        let stationary = ns_is_stationary(&state)
        var mutableBands = bands
        let rawType = ns_classify_noise(&mutableBands, crest, stationary)
        let typeLabel = NoiseTypeLabel(rawCType: rawType)
        let conf: Float = (bands.total_rms > 0.01) ? 0.7 : 0.4
        return (typeLabel, conf)
    }

    func extractBand(input: [Float], lowHz: Float, highHz: Float, sampleRate: Float = 16000) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)
        input.withUnsafeBufferPointer { inBuf in
            output.withUnsafeMutableBufferPointer { outBuf in
                ns_extract_band(inBuf.baseAddress, Int32(inBuf.count), sampleRate,
                                lowHz, highHz, outBuf.baseAddress)
            }
        }
        return output
    }

    struct NoiseLayer {
        let type: NoiseTypeLabel
        let confidence: Float
        let energy: Float
    }

    func decomposeMultiLayer(samples: [Float], sampleRate: Float = 16000) -> [NoiseLayer] {
        let result = samples.withUnsafeBufferPointer { buf in
            ns_decompose_multilayer(&state, buf.baseAddress, Int32(buf.count), sampleRate)
        }
        var layers: [NoiseLayer] = []
        for i in 0..<Int(result.layer_count) {
            let layer: ns_layer_t
            switch i {
            case 0: layer = result.layers.0
            case 1: layer = result.layers.1
            case 2: layer = result.layers.2
            case 3: layer = result.layers.3
            default: continue
            }
            layers.append(NoiseLayer(
                type: NoiseTypeLabel(rawCType: layer.type),
                confidence: layer.confidence,
                energy: layer.energy
            ))
        }
        return layers
    }

    static func extractFeaturesFromFile(_ url: URL) -> [String: Double] {
        guard let file = try? AVAudioFile(forReading: url) else { return [:] }
        let sr = Float(file.processingFormat.sampleRate)
        let frameCount = AVAudioFrameCount(min(file.length, 16000 * 10))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount),
              let _ = try? file.read(into: buffer, frameCount: frameCount),
              let channelData = buffer.floatChannelData else { return [:] }
        let count = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: count))

        let bridge = NoiseSeparatorBridge(fftSize: 1024, sampleRate: sr)
        let bands = bridge.computeBandEnergy(samples: samples, sampleRate: sr)

        let zcr: Double = {
            var crossings = 0
            for i in 1..<samples.count {
                if (samples[i] >= 0) != (samples[i-1] >= 0) { crossings += 1 }
            }
            return Double(crossings) / Double(max(samples.count - 1, 1))
        }()

        let spectralCentroid: Double = {
            let bandCenters: [(Double, Double)] = [
                (50,   Double(bands.subBass)),
                (165,  Double(bands.bass)),
                (375,  Double(bands.lowMid)),
                (1250, Double(bands.mid)),
                (3000, Double(bands.highMid)),
                (5000, Double(bands.presence)),
                (7000, Double(bands.brilliance)),
            ]
            let totalMag = bandCenters.reduce(0.0) { $0 + $1.1 }
            guard totalMag > 0 else { return 0 }
            return bandCenters.reduce(0.0) { $0 + $1.0 * $1.1 } / totalMag
        }()

        return [
            "sub_bass":  Double(bands.subBass),
            "bass":      Double(bands.bass),
            "low_mid":   Double(bands.lowMid),
            "mid":       Double(bands.mid),
            "high_mid":  Double(bands.highMid),
            "presence":  Double(bands.presence),
            "brilliance":Double(bands.brilliance),
            "rms_energy":Double(bands.totalRMS),
            "zero_crossing_rate": zcr,
            "spectral_centroid":  spectralCentroid,
        ]
    }
}

struct NoiseBandEnergy {
    let subBass: Float
    let bass: Float
    let lowMid: Float
    let mid: Float
    let highMid: Float
    let presence: Float
    let brilliance: Float
    let totalRMS: Float
}

enum NoiseTypeLabel: String, CaseIterable, Sendable {
    case quiet, wind, traffic, motorcycle, hvac, rain, speech, unknown

    init(rawCType: ns_noise_type_t) {
        switch rawCType {
        case NS_NOISE_QUIET: self = .quiet
        case NS_NOISE_WIND: self = .wind
        case NS_NOISE_TRAFFIC: self = .traffic
        case NS_NOISE_MOTORCYCLE: self = .motorcycle
        case NS_NOISE_HVAC: self = .hvac
        case NS_NOISE_RAIN: self = .rain
        case NS_NOISE_SPEECH: self = .speech
        default: self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .quiet: return L10n.calibrationQuiet
        case .wind: return L10n.sourceRain
        case .traffic: return L10n.sourceTraffic
        case .motorcycle: return L10n.sourceTraffic
        case .hvac: return L10n.sourceHVAC
        case .rain: return L10n.sourceRain
        case .speech: return L10n.eventSpeech
        case .unknown: return L10n.sourceUnknown
        }
    }

    var sfSymbol: String {
        switch self {
        case .quiet: return "speaker.slash.fill"
        case .wind: return "wind"
        case .traffic: return "car.fill"
        case .motorcycle: return "bicycle"
        case .hvac: return "fan.fill"
        case .rain: return "cloud.rain.fill"
        case .speech: return "person.wave.2.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    var toCType: ns_noise_type_t {
        switch self {
        case .quiet: return NS_NOISE_QUIET
        case .wind: return NS_NOISE_WIND
        case .traffic: return NS_NOISE_TRAFFIC
        case .motorcycle: return NS_NOISE_MOTORCYCLE
        case .hvac: return NS_NOISE_HVAC
        case .rain: return NS_NOISE_RAIN
        case .speech: return NS_NOISE_SPEECH
        case .unknown: return NS_NOISE_UNKNOWN
        }
    }

    var bandHz: (lo: Float, hi: Float) {
        switch self {
        case .quiet:      return (20, 200)
        case .wind:       return (20, 80)
        case .traffic:    return (80, 2000)
        case .motorcycle: return (80, 500)
        case .hvac:       return (80, 1000)
        case .rain:       return (1000, 8000)
        case .speech:     return (300, 4000)
        case .unknown:    return (20, 8000)
        }
    }
}
