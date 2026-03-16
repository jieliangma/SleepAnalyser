import SwiftUI
import SwiftData
import AVFoundation

struct NoiseTrainingDetailView: View {
    @Environment(AppState.self) private var appState
    let capture: NoiseCaptureRecorder.CaptureInfo

    @State private var segs: [NoiseSegment] = []
    @State private var amps: [Float] = []
    @State private var sourceTracks: [SourceTrack] = []
    @State private var isAnalyzing = false
    @State private var resolvedDuration: TimeInterval = 0

    @State private var zoomScale: CGFloat = 1.0
    @State private var panAccumulated: CGFloat = 0
    @State private var panDragBase: CGFloat = 0
    @State private var isDragging = false
    @State private var toolMode: WaveformTool = .select
    @State private var manualSelectStart: CGFloat?
    @State private var manualSelectEnd: CGFloat?
    @State private var showManualTypePicker = false
    @State private var manualTypeName: String = "traffic"
    @State private var editingSegment: NoiseSegment?
    @State private var hoveredWaveformId: UUID? = nil
    @State private var cursorMonitor: Any?
    @State private var selectedTrackIds: Set<UUID> = []
    @State private var isMixing = false
    @State private var separationTask: Task<Void, Never>?

    enum WaveformTool { case select, pan }

    struct SourceTrack: Identifiable {
        let id: UUID
        let layer: Int
        var noiseType: NoiseTypeLabel
        let confidence: Float
        let energy: Float
        var amps: [Float]
        var isConfirmed: Bool
        var userLabel: String?
        var audioClipURL: URL?
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                masterCard
                if isAnalyzing {
                    analyzingIndicator
                } else if !sourceTracks.isEmpty {
                    sourceTracksSection
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .navigationTitle(captureDateString(capture.date))
        .sheet(item: $editingSegment) { seg in
            NoiseSegmentEditorView(segment: seg, onSave: { updated in
                updateSegInCache(updated)
                Task { await saveAndRetrain(updated) }
            })
        }
        .sheet(isPresented: $showManualTypePicker) {
            manualTypePickerSheet
        }
        .task {
            amps = appState.noiseCaptureRecorder.loadAmplitudes(from: capture.directoryURL)
            resolvedDuration = resolveDuration()
            await loadSegs()
            cursorMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { [self] event in
                if hoveredWaveformId != nil { updateCursor() }
                return event
            }
        }
        .onDisappear {
            separationTask?.cancel()
            separationTask = nil
            if let m = cursorMonitor { NSEvent.removeMonitor(m); cursorMonitor = nil }
            NSCursor.arrow.set()
        }
    }

    private var analyzingIndicator: some View {
        HStack(spacing: AppSpacing.sm) {
            ProgressView().controlSize(.small)
            Text("正在分离声源...").font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
    }

    private var masterCard: some View {
        let isThisPlaying = appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == capture.id
        let displayDur = isThisPlaying ? appState.audioPlayer.currentTime : resolvedDuration

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Text(DurationFormatter.format(displayDur, style: .compact))
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Button {
                    guard let url = appState.noiseCaptureRecorder.audioURL(for: capture.directoryURL) else { return }
                    if isThisPlaying { appState.audioPlayer.stop() } else { appState.audioPlayer.play(url: url, eventId: capture.id) }
                } label: {
                    Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11)).foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)

                toolButtons

                Spacer()
                noiseSummaryBadges(segs)

                Button {
                    separationTask?.cancel()
                    isAnalyzing = true
                    separationTask = Task { await analyzeSourceTracks() }
                } label: {
                    Image(systemName: isAnalyzing ? "waveform" : "waveform.badge.plus")
                        .font(.system(size: 12)).foregroundStyle(isAnalyzing ? AppColors.textTertiary : AppColors.primary)
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzing)
                .help("分离声源")

                Button { Task { isAnalyzing = true; await reanalyze(); isAnalyzing = false } } label: {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .font(.system(size: 12)).foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
                .help("重新识别")
            }
            .padding(.horizontal, AppSpacing.cardPadding).padding(.top, AppSpacing.sm).padding(.bottom, 4)

            masterWaveform
            labelsAndConfirmRow
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private var toolButtons: some View {
        HStack(spacing: 0) {
            Button {
                toolMode = .select
                if hoveredWaveformId != nil { updateCursor() }
            } label: {
                Image(systemName: "text.cursor").font(.system(size: 11)).padding(4)
                    .background(toolMode == .select ? AppColors.primary.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(toolMode == .select ? AppColors.primary : AppColors.textTertiary)
            }.buttonStyle(.plain)
            Button {
                toolMode = .pan
                if hoveredWaveformId != nil { updateCursor() }
            } label: {
                Image(systemName: "hand.draw").font(.system(size: 11)).padding(4)
                    .background(toolMode == .pan ? AppColors.primary.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(toolMode == .pan ? AppColors.primary : AppColors.textTertiary)
            }.buttonStyle(.plain)
        }
    }

    private var masterWaveform: some View {
        GeometryReader { geo in
            let baseW = geo.size.width
            let totalW = baseW * zoomScale
            let maxOffset = max(0, totalW - baseW)
            let clampedOffset = min(max(0, -panAccumulated), maxOffset)

            TimelineView(.animation(minimumInterval: 0.05, paused: appState.audioPlayer.playingEventId != capture.id || !appState.audioPlayer.isPlaying)) { _ in
                Canvas { context, size in
                    let h = size.height, midY = h / 2
                    guard !amps.isEmpty else { return }
                    let maxAmp = amps.max() ?? 1
                    let ampScale: Float = maxAmp > 0 ? 1.0 / maxAmp : 1.0
                    let totalDur = capture.duration > 0 ? capture.duration : Double(amps.count) / 15.0
                    let visibleStart = clampedOffset / totalW
                    let visibleEnd = min(1.0, (clampedOffset + baseW) / totalW)
                    let layer0Segs = segs.filter { $0.layer == 0 }

                    for px in 0..<Int(baseW) {
                        let nx = visibleStart + Double(px) / Double(baseW) * (visibleEnd - visibleStart)
                        let srcIdx = nx * Double(amps.count)
                        let lo = max(0, min(Int(srcIdx), amps.count - 1))
                        let hi = min(lo + 1, amps.count - 1)
                        let frac = Float(srcIdx - Double(lo))
                        let amp = amps[lo] * (1 - frac) + amps[hi] * frac
                        let barH = max(Double(amp * ampScale) * h * 0.92, 0.5)
                        let t = nx * totalDur
                        let seg = layer0Segs.first { s in
                            let t0 = s.timestamp.timeIntervalSince(capture.date)
                            let t1 = s.endTime.timeIntervalSince(capture.date)
                            return t >= t0 && t < t1
                        }
                        let color = seg.map { noiseColor($0.noiseType).opacity(0.75) } ?? AppColors.primary.opacity(0.45)
                        var p = Path()
                        p.addRect(CGRect(x: Double(px), y: midY - barH / 2, width: 1, height: barH))
                        context.fill(p, with: .color(color))
                    }

                    if appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == capture.id && appState.audioPlayer.duration > 0 {
                        let frac = appState.audioPlayer.currentTime / appState.audioPlayer.duration
                        let px = (frac - visibleStart) / (visibleEnd - visibleStart) * Double(baseW)
                        if px >= 0 && px <= Double(baseW) {
                            var cur = Path()
                            cur.move(to: CGPoint(x: px, y: 0))
                            cur.addLine(to: CGPoint(x: px, y: h))
                            context.stroke(cur, with: .color(.white), lineWidth: 1)
                        }
                    }

                    if let s = manualSelectStart, let e = manualSelectEnd {
                        let x1 = min(s, e), x2 = max(s, e)
                        context.fill(Path(CGRect(x: Double(x1), y: 0, width: Double(x2 - x1), height: h)), with: .color(.white.opacity(0.2)))
                        context.stroke(Path(CGRect(x: Double(x1), y: 0, width: Double(x2 - x1), height: h)), with: .color(.white.opacity(0.6)), lineWidth: 1)
                    }
                }
                .frame(width: baseW, height: 100)
            }
            .frame(width: baseW, height: 100)
            .contentShape(Rectangle())
            .onHover { inside in
                hoveredWaveformId = inside ? capture.id : nil
                if inside { updateCursor() } else { NSCursor.arrow.set() }
            }
            .gesture(DragGesture(minimumDistance: 3).onChanged { val in
                if toolMode == .pan {
                    if !isDragging {
                        isDragging = true
                        panDragBase = panAccumulated
                        NSCursor.closedHand.set()
                    }
                    let newOff = panDragBase + val.translation.width
                    panAccumulated = max(-(totalW - baseW), min(0, newOff))
                } else {
                    manualSelectStart = val.startLocation.x
                    manualSelectEnd = val.location.x
                }
            }.onEnded { _ in
                if toolMode == .pan {
                    isDragging = false
                    updateCursor()
                } else if manualSelectStart != nil {
                    showManualTypePicker = true
                }
            })
            .onTapGesture { loc in
                if manualSelectStart != nil { manualSelectStart = nil; manualSelectEnd = nil; return }
                if appState.audioPlayer.duration > 0, appState.audioPlayer.playingEventId == capture.id {
                    let zoom = zoomScale
                    let pan = panAccumulated
                    let maxOff = max(0, geo.size.width * zoom - geo.size.width)
                    let clampedOff = min(max(0, -pan), maxOff)
                    let vStart = clampedOff / (geo.size.width * zoom)
                    let vEnd = min(1.0, (clampedOff + geo.size.width) / (geo.size.width * zoom))
                    let frac = vStart + loc.x / geo.size.width * (vEnd - vStart)
                    appState.audioPlayer.seek(to: frac * appState.audioPlayer.duration)
                }
            }
            .gesture(MagnificationGesture().onChanged { zoomScale = max(1.0, min(10.0, $0)) })
            .onScrollWheelZoom { delta in
                zoomScale = max(1.0, min(10.0, zoomScale + delta))
                panAccumulated = max(-(baseW * zoomScale - baseW), min(0, panAccumulated))
            }
        }
        .frame(height: 100)
        .padding(.horizontal, AppSpacing.cardPadding)
    }

    private var labelsAndConfirmRow: some View {
        let layer0 = segs.filter { $0.layer == 0 }
        var seen = Set<String>()
        let uniqueTypes = layer0.compactMap { seg -> String? in
            guard !seen.contains(seg.noiseType) else { return nil }
            seen.insert(seg.noiseType)
            return seg.noiseType
        }

        return HStack(spacing: 6) {
            ForEach(uniqueTypes, id: \.self) { type in
                let lbl = NoiseTypeLabel(rawValue: type) ?? .unknown
                HStack(spacing: 3) {
                    Circle().fill(noiseColor(type)).frame(width: 6, height: 6)
                    Text(lbl.displayName).font(.system(size: 10)).foregroundStyle(AppColors.textSecondary).fixedSize()
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(noiseColor(type).opacity(0.08))
                .clipShape(Capsule()).fixedSize()
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.cardPadding).padding(.vertical, 6)
    }

    private var sourceTracksSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("声源分离").font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Spacer()
                if selectedTrackIds.count >= 2 {
                    Button { playCombo() } label: {
                        if isMixing {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.mini)
                                Text("混音中...").font(.system(size: 11))
                            }
                            .foregroundStyle(AppColors.textTertiary)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(AppColors.surfaceLight)
                            .clipShape(Capsule())
                        } else {
                            Label("组合播放 (\(selectedTrackIds.count))", systemImage: "play.circle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppColors.primary)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(AppColors.primary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isMixing)
                } else if !sourceTracks.isEmpty {
                    Text("点击声源卡片可多选").font(.system(size: 10)).foregroundStyle(AppColors.textTertiary)
                }
            }
            ForEach($sourceTracks) { $track in
                SourceTrackView(
                    track: $track,
                    isSelected: selectedTrackIds.contains(track.id),
                    onTap: { toggleTrackSelection(track.id) },
                    onConfirm: { confirmed in persistSourceTrack(confirmed) }
                )
                .environment(appState)
            }
        }
    }

    private var manualTypePickerSheet: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(L10n.addNoiseType).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            Picker(L10n.eventTypeLabel, selection: $manualTypeName) {
                ForEach(appState.noiseTypeManager.types) { config in
                    Label(config.name, systemImage: config.sfSymbol).tag(config.name)
                }
            }
            .pickerStyle(.menu).labelsHidden()
            HStack(spacing: AppSpacing.md) {
                Button(L10n.cancel) { showManualTypePicker = false; manualSelectStart = nil; manualSelectEnd = nil }
                    .buttonStyle(.bordered)
                Button(L10n.confirmEvent) { addManualSegment(); showManualTypePicker = false }
                    .buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
        }
        .padding(AppSpacing.xl).frame(width: 350, height: 180)
    }

    private func noiseSummaryBadges(_ segments: [NoiseSegment]) -> some View {
        let counts = Dictionary(grouping: segments.filter { $0.layer == 0 }, by: \.noiseType).mapValues(\.count)
        let sorted = counts.sorted { $0.value > $1.value }.prefix(3)
        return HStack(spacing: 3) {
            ForEach(sorted, id: \.key) { type, count in
                HStack(spacing: 2) {
                    Circle().fill(noiseColor(type)).frame(width: 5, height: 5)
                    Text("\(count)").font(.system(size: 9)).foregroundStyle(AppColors.textTertiary)
                }
            }
        }
    }

    private func addManualSegment() {
        guard let s = manualSelectStart, let e = manualSelectEnd else { return }
        let totalDur = capture.duration > 0 ? capture.duration : max(1, Double(amps.count) / 15.0)
        let totalW = max(700, CGFloat(amps.count)) * zoomScale
        let t0 = Double(min(s, e)) / Double(totalW) * totalDur
        let t1 = Double(max(s, e)) / Double(totalW) * totalDur
        let seg = NoiseSegment(sessionId: capture.id, timestamp: capture.date.addingTimeInterval(t0),
                               endTime: capture.date.addingTimeInterval(t1),
                               noiseType: manualTypeName, confidence: 1.0, energyDB: 0, layer: 0)
        let context = appState.persistence.newBackgroundContext()
        context.insert(SDNoiseSegment(id: seg.id, sessionId: seg.sessionId, timestamp: seg.timestamp,
                                      endTime: seg.endTime, noiseType: seg.noiseType,
                                      confidence: seg.confidence, energyDB: seg.energyDB, layer: seg.layer))
        try? context.save()
        segs.append(seg)
        if let clipURL = appState.noiseCaptureRecorder.extractClip(from: capture.directoryURL, startTime: t0, endTime: t1, clipId: seg.id) {
            appState.noiseTypeManager.addSoundClip(to: manualTypeName, url: clipURL)
        }
        manualSelectStart = nil; manualSelectEnd = nil
    }

    private func analyzeSourceTracks() async {
        guard !Task.isCancelled else { return }
        guard let audioURL = appState.noiseCaptureRecorder.audioURL(for: capture.directoryURL) else {
            await MainActor.run { isAnalyzing = false }
            return
        }

        let captureDir = capture.directoryURL
        let captureId = capture.id
        let capDate = capture.date
        let capDur = resolvedDuration > 0 ? resolvedDuration : 1.0
        let ampBinCount = max(64, amps.count)
        let totalDur = capDur
        let localAmps = amps
        let retrainer = appState.mlRetrainer
        let persistence = appState.persistence

        let result = await Task.detached(priority: .userInitiated) { () -> [SourceTrack]? in
            guard !Task.isCancelled else { return nil }
            guard let audioFile = try? AVAudioFile(forReading: audioURL) else { return nil }

            let sr = audioFile.processingFormat.sampleRate
            let frameSize: AVAudioFrameCount = 2048
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameSize)!
            let separator = NoiseSeparatorBridge(fftSize: 1024, sampleRate: Float(sr))
            var layerVotes: [NoiseTypeLabel: (totalEnergy: Float, frames: Int, peakBins: [Int: Float])] = [:]
            var warmupFrames = 0
            let warmupNeeded = 10

            while audioFile.framePosition < audioFile.length {
                guard !Task.isCancelled else { return nil }
                do { try audioFile.read(into: buffer, frameCount: frameSize) } catch { break }
                guard let channelData = buffer.floatChannelData else { break }
                let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
                separator.updateNoiseFloor(samples: samples)
                warmupFrames += 1
                guard warmupFrames > warmupNeeded else { continue }

                let layers = separator.decomposeMultiLayer(samples: samples)
                guard layers.count > 0 else { continue }

                let elapsed = Double(audioFile.framePosition) / sr
                let binIdx = min(Int(elapsed / totalDur * Double(ampBinCount)), ampBinCount - 1)

                for layer in layers where layer.energy > 0.001 {
                    if var entry = layerVotes[layer.type] {
                        entry.totalEnergy += layer.energy
                        entry.frames += 1
                        let prev = entry.peakBins[binIdx] ?? 0
                        entry.peakBins[binIdx] = max(prev, layer.energy)
                        layerVotes[layer.type] = entry
                    } else {
                        layerVotes[layer.type] = (layer.energy, 1, [binIdx: layer.energy])
                    }
                }
            }

            guard !Task.isCancelled else { return nil }

            var tracks: [SourceTrack] = []
            let bgContext = persistence.newBackgroundContext()

            for (noiseType, info) in layerVotes.sorted(by: { $0.value.totalEnergy > $1.value.totalEnergy })
                where info.frames >= 2 {
                guard !Task.isCancelled else { return nil }

                var trackAmps = [Float](repeating: 0, count: ampBinCount)
                for (bin, energy) in info.peakBins { trackAmps[bin] = energy }
                let maxE = trackAmps.max() ?? 1
                if maxE > 0 { trackAmps = trackAmps.map { $0 / maxE } }
                let avgConf: Float = min(info.totalEnergy / Float(info.frames) * 5, 0.95)
                let avgEnergy = info.totalEnergy / Float(max(info.frames, 1))
                let energyDB = avgEnergy > 0 ? Double(20 * log10(avgEnergy)) : -60.0
                let layerIdx = tracks.count + 1

                let existingPred = #Predicate<SDNoiseSegment> {
                    $0.sessionId == captureId && $0.layer == layerIdx
                }
                let existingSD = try? bgContext.fetch(FetchDescriptor<SDNoiseSegment>(predicate: existingPred)).first
                let segId: UUID
                if let sd = existingSD {
                    segId = sd.id
                    sd.noiseType = noiseType.rawValue
                    sd.confidence = Double(avgConf)
                    sd.energyDB = energyDB
                } else {
                    segId = UUID()
                    bgContext.insert(SDNoiseSegment(
                        id: segId, sessionId: captureId,
                        timestamp: capDate, endTime: capDate.addingTimeInterval(capDur),
                        noiseType: noiseType.rawValue, confidence: Double(avgConf),
                        energyDB: energyDB, layer: layerIdx
                    ))
                }

                let sourceClipURL = captureDir.appendingPathComponent("source_\(layerIdx).caf")
                let existingClipPath = existingSD?.audioClipPath
                let clipURL: URL?
                if FileManager.default.fileExists(atPath: sourceClipURL.path) {
                    clipURL = sourceClipURL
                } else if let p = existingClipPath, FileManager.default.fileExists(atPath: p) {
                    clipURL = URL(fileURLWithPath: p)
                } else if !Task.isCancelled {
                    let pcmSettings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: sr,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 32,
                        AVLinearPCMIsFloatKey: true,
                        AVLinearPCMIsBigEndianKey: false,
                    ]
                    clipURL = Self.writeBandAudio(
                        sourceURL: audioURL, outputURL: sourceClipURL,
                        noiseType: noiseType, sampleRate: Float(sr),
                        pcmSettings: pcmSettings
                    )
                } else {
                    return nil
                }

                if let clipURL {
                    let clipPred = #Predicate<SDNoiseSegment> { $0.id == segId }
                    if let sd = try? bgContext.fetch(FetchDescriptor<SDNoiseSegment>(predicate: clipPred)).first {
                        sd.audioClipPath = clipURL.path
                    }
                }

                tracks.append(SourceTrack(
                    id: segId, layer: layerIdx, noiseType: noiseType,
                    confidence: avgConf, energy: avgEnergy,
                    amps: trackAmps, isConfirmed: existingSD?.isConfirmed ?? false,
                    userLabel: existingSD?.userLabel, audioClipURL: clipURL
                ))
            }

            try? bgContext.save()
            return tracks
        }.value

        await MainActor.run {
            if let tracks = result {
                sourceTracks = tracks
            }
            isAnalyzing = false
        }
    }

    private static func writeBandAudio(
        sourceURL: URL, outputURL: URL,
        noiseType: NoiseTypeLabel, sampleRate: Float,
        pcmSettings: [String: Any]
    ) -> URL? {
        guard let sourceFile = try? AVAudioFile(forReading: sourceURL) else { return nil }
        let frameCount = AVAudioFrameCount(sourceFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: sourceFile.processingFormat, frameCapacity: frameCount),
              let _ = try? sourceFile.read(into: buffer, frameCount: frameCount),
              let channelData = buffer.floatChannelData else { return nil }
        let separator = NoiseSeparatorBridge(fftSize: 1024, sampleRate: sampleRate)
        let (lo, hi) = noiseType.bandHz
        let count = Int(buffer.frameLength)
        let filtered = separator.extractBand(
            input: Array(UnsafeBufferPointer(start: channelData[0], count: count)),
            lowHz: lo, highHz: hi, sampleRate: sampleRate
        )
        guard let outFile = try? AVAudioFile(forWriting: outputURL, settings: pcmSettings),
              let pcmFormat = AVAudioFormat(settings: pcmSettings),
              let outBuffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(count)) else { return nil }
        outBuffer.frameLength = AVAudioFrameCount(count)
        if let outData = outBuffer.floatChannelData {
            filtered.withUnsafeBufferPointer { src in
                outData[0].update(from: src.baseAddress!, count: count)
            }
        }
        guard let _ = try? outFile.write(from: outBuffer) else { return nil }
        return outputURL
    }

    private func reanalyze() async {
        guard let audioURL = appState.noiseCaptureRecorder.audioURL(for: capture.directoryURL),
              let audioFile = try? AVAudioFile(forReading: audioURL) else { return }

        let captureId = capture.id
        let context = appState.persistence.newBackgroundContext()
        let predicate = #Predicate<SDNoiseSegment> { $0.sessionId == captureId }
        let existing = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        for sd in existing { context.delete(sd) }
        try? context.save()

        let separator = NoiseSeparatorBridge()
        let sr = audioFile.processingFormat.sampleRate
        let frameSize: AVAudioFrameCount = 1024
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameSize)!
        var segStart = capture.date
        var currentType: NoiseTypeLabel = .quiet
        var rawSegs: [NoiseSegment] = []
        let bgContext = appState.persistence.newBackgroundContext()

        while audioFile.framePosition < audioFile.length {
            do { try audioFile.read(into: buffer, frameCount: frameSize) } catch { break }
            guard let channelData = buffer.floatChannelData else { break }
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
            separator.updateNoiseFloor(samples: samples)
            let (noiseType, conf) = separator.classifyNoise(samples: samples)
            let elapsed = Double(audioFile.framePosition) / sr
            let frameTime = capture.date.addingTimeInterval(elapsed)

            if noiseType != .quiet && conf > 0.3 && frameTime.timeIntervalSince(segStart) > 0.5 {
                if noiseType != currentType {
                    let seg = NoiseSegment(sessionId: captureId, timestamp: segStart, endTime: frameTime,
                                          noiseType: noiseType.rawValue, confidence: Double(conf), energyDB: -30, layer: 0)
                    rawSegs.append(seg)
                    currentType = noiseType
                }
                segStart = frameTime
            } else if noiseType == .quiet {
                currentType = .quiet
                segStart = frameTime
            }
        }

        let mergedSegs = mergeSegments(rawSegs, gapTolerance: 1.0)
        for seg in mergedSegs {
            bgContext.insert(SDNoiseSegment(id: seg.id, sessionId: seg.sessionId, timestamp: seg.timestamp,
                                            endTime: seg.endTime, noiseType: seg.noiseType,
                                            confidence: seg.confidence, energyDB: seg.energyDB, layer: 0))
        }
        try? bgContext.save()
        await MainActor.run {
            segs = mergedSegs
            separationTask?.cancel()
            isAnalyzing = true
            separationTask = Task { await analyzeSourceTracks() }
        }
    }

    private func mergeSegments(_ segs: [NoiseSegment], gapTolerance: TimeInterval) -> [NoiseSegment] {
        guard !segs.isEmpty else { return [] }
        var sorted = segs.sorted { $0.timestamp < $1.timestamp }
        var result: [NoiseSegment] = []
        var current = sorted[0]

        for next in sorted.dropFirst() {
            let gap = next.timestamp.timeIntervalSince(current.endTime)
            if next.noiseType == current.noiseType && gap < gapTolerance {
                current = NoiseSegment(
                    id: current.id, sessionId: current.sessionId,
                    timestamp: current.timestamp, endTime: next.endTime,
                    noiseType: current.noiseType,
                    confidence: max(current.confidence, next.confidence),
                    energyDB: current.energyDB, layer: 0
                )
            } else {
                result.append(current)
                current = next
            }
        }
        result.append(current)
        return result
    }

    private func persistSourceTrack(_ track: SourceTrack) {
        let context = appState.persistence.newBackgroundContext()
        let trackId = track.id
        let predicate = #Predicate<SDNoiseSegment> { $0.id == trackId }
        let energyDB = track.energy > 0 ? Double(20 * log10(track.energy)) : -60.0
        if let existing = try? context.fetch(FetchDescriptor<SDNoiseSegment>(predicate: predicate)).first {
            existing.noiseType = track.noiseType.rawValue
            existing.isConfirmed = track.isConfirmed
            existing.userLabel = track.userLabel
        } else {
            let capDur = resolvedDuration > 0 ? resolvedDuration : 1.0
            context.insert(SDNoiseSegment(
                id: track.id, sessionId: capture.id,
                timestamp: capture.date, endTime: capture.date.addingTimeInterval(capDur),
                noiseType: track.noiseType.rawValue, confidence: Double(track.confidence),
                energyDB: energyDB, layer: track.layer
            ))
        }
        try? context.save()
        guard track.isConfirmed else { return }
        let clipURL = track.audioClipURL
        let noiseType = track.noiseType.rawValue
        let segId = track.id
        Task.detached(priority: .utility) { [retrainer = appState.mlRetrainer] in
            let features: [String: Double]
            if let url = clipURL {
                features = NoiseSeparatorBridge.extractFeaturesFromFile(url)
            } else {
                features = ["rms_energy": Double(pow(10.0 as Float, Float(energyDB) / 20.0))]
            }
            retrainer.addConfirmedSample(noiseType: noiseType, features: features, segmentId: segId)
        }
    }

    private func toggleTrackSelection(_ id: UUID) {
        if selectedTrackIds.contains(id) { selectedTrackIds.remove(id) }
        else { selectedTrackIds.insert(id) }
    }

    private func playCombo() {
        let selectedURLs = sourceTracks
            .filter { selectedTrackIds.contains($0.id) }
            .compactMap { $0.audioClipURL }
        guard !selectedURLs.isEmpty else { return }

        if selectedURLs.count == 1 {
            let id = sourceTracks.first(where: { selectedTrackIds.contains($0.id) && $0.audioClipURL != nil })?.id
            appState.audioPlayer.play(url: selectedURLs[0], eventId: id)
            return
        }

        let comboId = UUID()
        Task {
            isMixing = true
            let mixURL = await mixAudio(urls: selectedURLs, comboId: comboId)
            isMixing = false
            if let url = mixURL {
                appState.audioPlayer.play(url: url, eventId: comboId)
            }
        }
    }

    private func mixAudio(urls: [URL], comboId: UUID) async -> URL? {
        return await Task.detached(priority: .userInitiated) {
            let engine = AVAudioEngine()
            let mixer = engine.mainMixerNode

            var players: [AVAudioPlayerNode] = []
            var buffers: [(AVAudioPlayerNode, AVAudioPCMBuffer)] = []
            var maxLength: AVAudioFramePosition = 0

            for url in urls {
                guard let file = try? AVAudioFile(forReading: url),
                      let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                  frameCapacity: AVAudioFrameCount(file.length)),
                      let _ = try? file.read(into: buf) else { continue }
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: mixer, format: file.processingFormat)
                buffers.append((node, buf))
                players.append(node)
                maxLength = max(maxLength, file.length)
            }
            guard !players.isEmpty, let format = buffers.first?.1.format else { return nil }

            let outURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("combo_\(comboId.uuidString.prefix(8)).m4a")
            guard let outFile = try? AVAudioFile(forWriting: outURL, settings: format.settings) else { return nil }

            engine.prepare()
            guard let _ = try? engine.start() else { return nil }
            for (node, buf) in buffers { node.scheduleBuffer(buf); node.play() }

            let outBuf = AVAudioPCMBuffer(pcmFormat: format,
                                           frameCapacity: AVAudioFrameCount(maxLength))!
            outBuf.frameLength = AVAudioFrameCount(maxLength)

            let sinkNode = engine.outputNode
            sinkNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buf, _ in
                try? outFile.write(from: buf)
            }

            Thread.sleep(forTimeInterval: Double(maxLength) / format.sampleRate + 0.2)
            sinkNode.removeTap(onBus: 0)
            engine.stop()
            return outURL
        }.value
    }

    private func loadSegs() async {
        let captureId = capture.id
        let context = appState.persistence.newBackgroundContext()
        let predicate = #Predicate<SDNoiseSegment> { $0.sessionId == captureId }
        let all = (try? context.fetch(FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.timestamp)]))) ?? []
        let mapped = all.map { sd in
            NoiseSegment(id: sd.id, sessionId: sd.sessionId, timestamp: sd.timestamp,
                         endTime: sd.endTime, noiseType: sd.noiseType, confidence: sd.confidence,
                         energyDB: sd.energyDB, audioClipURL: sd.audioClipPath.flatMap { URL(fileURLWithPath: $0) },
                         isConfirmed: sd.isConfirmed, userLabel: sd.userLabel, layer: sd.layer)
        }
        let layerSegs = all.filter { $0.layer > 0 }.sorted { $0.layer < $1.layer }
        let ampBinCount = max(64, amps.count)
        let totalDur = resolvedDuration > 0 ? resolvedDuration : max(1, Double(amps.count) / 15.0)
        let restoredTracks: [SourceTrack] = layerSegs.compactMap { sd in
            guard let type = NoiseTypeLabel(rawValue: sd.noiseType) else { return nil }
            let segDur = sd.endTime.timeIntervalSince(sd.timestamp)
            let startRatio = sd.timestamp.timeIntervalSince(capture.date) / totalDur
            let endRatio = min(1.0, startRatio + segDur / totalDur)
            let startBin = Int(startRatio * Double(ampBinCount))
            let endBin = min(ampBinCount, Int(endRatio * Double(ampBinCount)))
            var trackAmps = [Float](repeating: 0, count: ampBinCount)
            if !amps.isEmpty {
                let maxAmp = amps.max() ?? 1
                for bin in startBin..<endBin where bin < amps.count {
                    trackAmps[bin] = amps[bin] / max(maxAmp, 1)
                }
            }
            return SourceTrack(
                id: sd.id, layer: sd.layer,
                noiseType: type, confidence: Float(sd.confidence),
                energy: Float(pow(10.0, sd.energyDB / 20.0)),
                amps: trackAmps, isConfirmed: sd.isConfirmed,
                userLabel: sd.userLabel,
                audioClipURL: sd.audioClipPath.flatMap { URL(fileURLWithPath: $0) }
            )
        }
        await MainActor.run {
            segs = mapped
            if !restoredTracks.isEmpty { sourceTracks = restoredTracks }
        }
    }

    private func updateSegInCache(_ seg: NoiseSegment) {
        if let idx = segs.firstIndex(where: { $0.id == seg.id }) { segs[idx] = seg }
    }

    private func saveAndRetrain(_ seg: NoiseSegment) async {
        let context = appState.persistence.newBackgroundContext()
        let id = seg.id
        let predicate = #Predicate<SDNoiseSegment> { $0.id == id }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.noiseType = seg.noiseType
            existing.isConfirmed = seg.isConfirmed
            existing.userLabel = seg.userLabel
            try? context.save()
        }
        if seg.isConfirmed {
            appState.mlRetrainer.addConfirmedSample(
                noiseType: seg.displayType,
                features: ["rms_energy": Double(pow(10.0 as Float, Float(seg.energyDB) / 20.0))],
                segmentId: seg.id
            )
        }
    }

    private func updateCursor() {
        if isDragging {
            NSCursor.closedHand.set()
        } else if toolMode == .pan {
            NSCursor.openHand.set()
        } else {
            NSCursor.iBeam.set()
        }
    }

    private func noiseColor(_ type: String) -> Color {
        Color(hex: appState.noiseTypeManager.colorHex(for: type))
    }

    private func resolveDuration() -> TimeInterval {
        if capture.duration > 0 { return capture.duration }
        if let url = appState.noiseCaptureRecorder.audioURL(for: capture.directoryURL),
           let file = try? AVAudioFile(forReading: url) {
            return Double(file.length) / file.processingFormat.sampleRate
        }
        if !amps.isEmpty { return Double(amps.count) / 15.0 }
        if capture.size > 0 { return Double(capture.size) / 4.0 / 16000.0 }
        return 0
    }

    private func captureDateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        fmt.locale = Locale(identifier: LanguageManager.shared.effectiveLanguageCode)
        return fmt.string(from: date)
    }
}

private struct SourceTrackView: View {
    @Environment(AppState.self) private var appState
    @Binding var track: NoiseTrainingDetailView.SourceTrack
    let isSelected: Bool
    let onTap: () -> Void
    let onConfirm: (NoiseTrainingDetailView.SourceTrack) -> Void

    @State private var selectedType: String = ""

    private var isPlaying: Bool {
        appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == track.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: track.noiseType.sfSymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(noiseColor(track.noiseType.rawValue))
                Text(track.noiseType.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                Text(String(format: "%.0f%%", track.confidence * 100))
                    .font(.system(size: 10)).foregroundStyle(AppColors.textTertiary)

                Button {
                    guard let url = track.audioClipURL else { return }
                    if isPlaying { appState.audioPlayer.stop() }
                    else { appState.audioPlayer.play(url: url, eventId: track.id) }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(track.audioClipURL != nil ? AppColors.primary : AppColors.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(track.audioClipURL == nil)
                .help(track.audioClipURL == nil ? "声源音频生成中..." : "")

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.primary)
                }

                Picker("", selection: $selectedType) {
                    ForEach(NoiseTypeLabel.allCases, id: \.rawValue) { t in
                        Label(t.displayName, systemImage: t.sfSymbol).tag(t.rawValue)
                    }
                }
                .pickerStyle(.menu).labelsHidden()
                .frame(width: 110)
                .font(.system(size: 11))
                .onChange(of: selectedType) { _, newVal in
                    track.noiseType = NoiseTypeLabel(rawValue: newVal) ?? track.noiseType
                    onConfirm(track)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding).padding(.vertical, AppSpacing.sm)

            sourceWaveform
        }
        .background(isSelected ? AppColors.primary.opacity(0.06) : AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(isSelected ? AppColors.primary.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear { selectedType = track.noiseType.rawValue }
    }

    private var sourceWaveform: some View {
        GeometryReader { geo in
            let baseW = geo.size.width
            TimelineView(.animation(minimumInterval: 0.05, paused: !isPlaying)) { _ in
                Canvas { context, size in
                    let h = size.height, midY = h / 2
                    guard !track.amps.isEmpty else { return }
                    let maxAmp = track.amps.max() ?? 1
                    let scale: Float = maxAmp > 0 ? 1.0 / maxAmp : 1.0
                    let baseColor = noiseColor(track.noiseType.rawValue)
                    let fillColor = isSelected ? baseColor.opacity(0.85) : baseColor.opacity(0.65)
                    for (i, amp) in track.amps.enumerated() {
                        let x = Double(i) / Double(track.amps.count) * Double(baseW)
                        let barH = max(Double(amp * scale) * h * 0.9, 0.5)
                        var p = Path()
                        p.addRect(CGRect(x: x, y: midY - barH / 2,
                                         width: max(1, Double(baseW) / Double(track.amps.count)), height: barH))
                        context.fill(p, with: .color(fillColor))
                    }
                    if isPlaying && appState.audioPlayer.duration > 0 {
                        let frac = appState.audioPlayer.currentTime / appState.audioPlayer.duration
                        let px = frac * Double(baseW)
                        if px >= 0 && px <= Double(baseW) {
                            var cur = Path()
                            cur.move(to: CGPoint(x: px, y: 0))
                            cur.addLine(to: CGPoint(x: px, y: h))
                            context.stroke(cur, with: .color(.white), lineWidth: 1)
                        }
                    }
                }
                .frame(width: baseW, height: 50)
            }
            .frame(width: baseW, height: 50)
        }
        .frame(height: 50)
        .padding(.horizontal, AppSpacing.cardPadding).padding(.bottom, AppSpacing.sm)
    }

    private func noiseColor(_ type: String) -> Color {
        Color(hex: appState.noiseTypeManager.colorHex(for: type))
    }
}

struct NoiseSegmentEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State var segment: NoiseSegment
    let onSave: (NoiseSegment) -> Void
    @State private var selectedType: String
    @State private var userNote: String

    init(segment: NoiseSegment, onSave: @escaping (NoiseSegment) -> Void) {
        self._segment = State(initialValue: segment)
        self.onSave = onSave
        self._selectedType = State(initialValue: segment.noiseType)
        self._userNote = State(initialValue: segment.userLabel ?? "")
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(L10n.editNoiseSegment).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
            if let url = segment.audioClipURL {
                HStack {
                    Button {
                        appState.audioPlayer.toggle(url: url, eventId: segment.id)
                    } label: {
                        Image(systemName: appState.audioPlayer.playingEventId == segment.id ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28)).foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    if appState.audioPlayer.playingEventId == segment.id {
                        ProgressView(value: appState.audioPlayer.duration > 0 ? appState.audioPlayer.currentTime / appState.audioPlayer.duration : 0)
                            .tint(AppColors.primary)
                    } else {
                        RoundedRectangle(cornerRadius: 2).fill(AppColors.surfaceLight).frame(height: 4)
                    }
                }
                .padding(AppSpacing.cardPadding).background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            }
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(L10n.eventTypeLabel).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                Picker(L10n.eventTypeLabel, selection: $selectedType) {
                    ForEach(NoiseTypeLabel.allCases, id: \.rawValue) { type in
                        Label(type.displayName, systemImage: type.sfSymbol).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu).labelsHidden()
            }
            .padding(AppSpacing.cardPadding).background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(L10n.noteLabel).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                TextField(L10n.notePlaceholder, text: $userNote).textFieldStyle(.roundedBorder)
            }
            .padding(AppSpacing.cardPadding).background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            HStack(spacing: AppSpacing.md) {
                Button(L10n.cancel) { dismiss() }.buttonStyle(.bordered)
                Button(L10n.confirmEvent) {
                    segment.noiseType = selectedType
                    segment.userLabel = userNote.isEmpty ? nil : userNote
                    segment.isConfirmed = true
                    onSave(segment)
                    dismiss()
                }
                .buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
        }
        .padding(AppSpacing.xl).frame(minWidth: 400, minHeight: 300)
    }
}
