import SwiftUI
import SwiftData

struct NoiseAnalysisView: View {
    @Environment(AppState.self) private var appState
    @State private var segments: [NoiseSegment] = []
    @State private var editingSegment: NoiseSegment?
    @State private var isCapturing = false
    @State private var liveNoiseType: String = "unknown"
    @State private var liveDB: Double = -50
    @State private var captureTask: Task<Void, Never>?
    @State private var captures: [NoiseCaptureRecorder.CaptureInfo] = []
    @State private var ampCache: [UUID: [Float]] = [:]
    @State private var segCache: [UUID: [NoiseSegment]] = [:]
    @State private var zoomScale: CGFloat = 1.0
    @State private var manualSelectStart: CGFloat?
    @State private var manualSelectEnd: CGFloat?
    @State private var manualSelectCaptureId: UUID?
    @State private var showManualTypePicker = false
    @State private var manualTypeName: String = "traffic"

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                header
                if isCapturing { liveWaveform }
                ForEach(captures) { cap in
                    captureCard(cap)
                }
                if captures.isEmpty && !isCapturing {
                    emptyState
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .task {
            captures = appState.noiseCaptureRecorder.allCaptures()
            await loadAllSegments()
        }
        .sheet(item: $editingSegment) { seg in
            NoiseSegmentEditorView(segment: seg, onSave: { updated in
                updateSegmentInCache(updated)
                Task { await saveAndRetrain(updated) }
            })
        }
        .sheet(isPresented: $showManualTypePicker) {
            manualTypePickerSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(L10n.noiseAnalysis).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
            Spacer()
            if isCapturing {
                HStack(spacing: 4) {
                    Circle().fill(AppColors.error).frame(width: 6, height: 6)
                    Text((NoiseTypeLabel(rawValue: liveNoiseType) ?? .unknown).displayName)
                        .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    Text(String(format: "%.0f dB", liveDB))
                        .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                }
            }
            Button {
                if isCapturing { stopCapture() } else { startCapture() }
            } label: {
                Label(isCapturing ? L10n.stopCapture : L10n.startCapture,
                      systemImage: isCapturing ? "stop.fill" : "mic.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCapturing ? .white : AppColors.primary)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(isCapturing ? AppColors.error : AppColors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "waveform.badge.magnifyingglass").font(.system(size: 48)).foregroundStyle(AppColors.textTertiary)
            Text(L10n.noNoiseSegments).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, 60)
    }

    private var liveWaveform: some View {
        let liveSegs = segCache[appState.noiseCaptureRecorder.captureId ?? UUID()] ?? []
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(AppColors.error).frame(width: 6, height: 6)
                Text(L10n.recording).font(AppTypography.caption).foregroundStyle(AppColors.error)
                Spacer()
                Text((NoiseTypeLabel(rawValue: liveNoiseType) ?? .unknown).displayName)
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(noiseColor(liveNoiseType))
                Text(String(format: "%.0f dB", liveDB))
                    .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.cardPadding)

            TimelineView(.animation(minimumInterval: 0.12)) { _ in
                Canvas { context, size in
                    let w = size.width, h = size.height, midY = h / 2
                    let liveAmps = appState.noiseCaptureRecorder.amplitudes
                    guard !liveAmps.isEmpty else { return }
                    let maxA = liveAmps.max() ?? 1
                    let s: Float = maxA > 0 ? 1.0 / maxA : 1
                    let visibleCount = min(liveAmps.count, Int(w))
                    let startIdx = max(0, liveAmps.count - visibleCount)
                    let totalSamples = Double(liveAmps.count)
                    let captureStart = appState.noiseCaptureRecorder.startTime ?? Date()
                    let elapsed = Date().timeIntervalSince(captureStart)

                    for seg in liveSegs {
                        let t0 = seg.timestamp.timeIntervalSince(captureStart)
                        let t1 = seg.endTime.timeIntervalSince(captureStart)
                        guard elapsed > 0 else { continue }
                        let visibleStart = Double(startIdx) / totalSamples * elapsed
                        let visibleEnd = elapsed
                        let sx = max(0, (t0 - visibleStart) / (visibleEnd - visibleStart) * w)
                        let ex = min(w, (t1 - visibleStart) / (visibleEnd - visibleStart) * w)
                        if ex > sx {
                            context.fill(Path(CGRect(x: sx, y: 0, width: ex - sx, height: h)),
                                         with: .color(noiseColor(seg.noiseType).opacity(0.15)))
                        }
                    }

                    for i in 0..<visibleCount {
                        let amp = liveAmps[startIdx + i]
                        let x = Double(i)
                        let barH = Double(amp * s) * h * 0.9
                        var p = Path()
                        p.addRect(CGRect(x: x, y: midY - barH / 2, width: 1, height: max(barH, 0.5)))
                        context.fill(p, with: .color(noiseColor(liveNoiseType).opacity(0.7)))
                    }
                }
                .frame(height: 80)
            }

            if !liveSegs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(liveSegs.suffix(10)) { seg in
                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 1).fill(noiseColor(seg.noiseType)).frame(width: 3, height: 12)
                                Text((NoiseTypeLabel(rawValue: seg.noiseType) ?? .unknown).displayName)
                                    .font(.system(size: 9)).foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(noiseColor(seg.noiseType).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                }
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Per-Capture Card

    private func captureCard(_ cap: NoiseCaptureRecorder.CaptureInfo) -> some View {
        let segs = segCache[cap.id] ?? []
        let amps = ampCache[cap.id] ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "calendar").foregroundStyle(AppColors.textTertiary)
                Text(cap.date, format: .dateTime.year().month().day().weekday().hour().minute())
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Spacer()
                if !segs.isEmpty {
                    noiseSummaryBadges(segs)
                }
                Text(formatSize(cap.size)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                Button {
                    if appState.audioPlayer.playingEventId == cap.id { appState.audioPlayer.stop() }
                    appState.noiseCaptureRecorder.deleteCapture(cap)
                    captures = appState.noiseCaptureRecorder.allCaptures()
                    ampCache.removeValue(forKey: cap.id)
                    segCache.removeValue(forKey: cap.id)
                } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(AppColors.error.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.cardPadding).padding(.top, AppSpacing.sm).padding(.bottom, 4)

            waveformView(amps: amps, segs: segs, capture: cap)
            labelRows(segs: segs, capture: cap, amps: amps)
            confirmBar(capture: cap, segs: segs)
            playbackBar(capture: cap)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .onAppear {
            if ampCache[cap.id] == nil {
                ampCache[cap.id] = appState.noiseCaptureRecorder.loadAmplitudes(from: cap.directoryURL)
            }
        }
    }

    // MARK: - Waveform

    private func waveformView(amps: [Float], segs: [NoiseSegment], capture: NoiseCaptureRecorder.CaptureInfo) -> some View {
        let minW: CGFloat = 700
        let naturalW = CGFloat(amps.count)
        let baseW = max(minW, naturalW)

        return GeometryReader { geo in
            let totalW = max(baseW, baseW * zoomScale)
            ScrollView(.horizontal, showsIndicators: true) {
                Canvas { context, size in
                    let w = size.width, h = size.height, midY = h / 2
                    guard !amps.isEmpty else { return }

                    let maxAmp = amps.max() ?? 1
                    let ampScale: Float = maxAmp > 0 ? 1.0 / maxAmp : 1.0
                    let totalDur = appState.audioPlayer.duration > 0
                        ? appState.audioPlayer.duration
                        : Double(amps.count) * 0.3
                    let maxLayer = (segs.map(\.layer).max() ?? 0) + 1
                    let bandH = h / Double(max(maxLayer, 1))

                    for seg in segs {
                        let t0 = seg.timestamp.timeIntervalSince(capture.date)
                        let t1 = seg.endTime.timeIntervalSince(capture.date)
                        guard t1 > 0, t0 < totalDur else { continue }
                        let x1 = max(0, t0 / totalDur * w)
                        let x2 = min(w, t1 / totalDur * w)
                        let y = Double(seg.layer) * bandH
                        context.fill(
                            Path(CGRect(x: x1, y: y, width: x2 - x1, height: bandH)),
                            with: .color(noiseColor(seg.noiseType).opacity(0.18))
                        )
                    }

                    for (i, amp) in amps.enumerated() {
                        let x = Double(i) / Double(amps.count) * w
                        let norm = Double(amp * ampScale)
                        let barH = max(norm * h * 0.92, 0.5)
                        let sampleTime = Double(i) / Double(amps.count) * totalDur
                        let dominantSeg = segs.first { seg in
                            let t0 = seg.timestamp.timeIntervalSince(capture.date)
                            let t1 = seg.endTime.timeIntervalSince(capture.date)
                            return seg.layer == 0 && sampleTime >= t0 && sampleTime < t1
                        }
                        let barColor = dominantSeg != nil
                            ? noiseColor(dominantSeg!.noiseType).opacity(0.75)
                            : AppColors.primary.opacity(0.45)
                        var p = Path()
                        p.addRect(CGRect(x: x, y: midY - barH / 2, width: 1, height: barH))
                        context.fill(p, with: .color(barColor))
                    }

                    if appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == capture.id && appState.audioPlayer.duration > 0 {
                        let px = appState.audioPlayer.currentTime / appState.audioPlayer.duration * w
                        var cursor = Path()
                        cursor.move(to: CGPoint(x: px, y: 0))
                        cursor.addLine(to: CGPoint(x: px, y: h))
                        context.stroke(cursor, with: .color(.white), lineWidth: 1)
                    }

                    if manualSelectCaptureId == capture.id,
                       let s = manualSelectStart, let e = manualSelectEnd {
                        let x1 = min(s, e), x2 = max(s, e)
                        context.fill(
                            Path(CGRect(x: Double(x1), y: 0, width: Double(x2 - x1), height: h)),
                            with: .color(Color.white.opacity(0.2))
                        )
                        context.stroke(
                            Path(CGRect(x: Double(x1), y: 0, width: Double(x2 - x1), height: h)),
                            with: .color(.white.opacity(0.6)), lineWidth: 1
                        )
                    }
                }
                .frame(width: totalW, height: 100)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { val in
                            manualSelectCaptureId = capture.id
                            manualSelectStart = val.startLocation.x
                            manualSelectEnd = val.location.x
                        }
                        .onEnded { _ in
                            showManualTypePicker = true
                        }
                )
                .onTapGesture { loc in
                    if manualSelectStart != nil {
                        manualSelectStart = nil; manualSelectEnd = nil; manualSelectCaptureId = nil
                    } else if appState.audioPlayer.duration > 0, appState.audioPlayer.playingEventId == capture.id {
                        appState.audioPlayer.seek(to: loc.x / totalW * appState.audioPlayer.duration)
                    }
                }
                .gesture(MagnificationGesture().onChanged { val in
                    zoomScale = max(1.0, min(10.0, val))
                })
            }
        }
        .frame(height: 100)
    }

    // MARK: - Label Row

    private func labelRows(segs: [NoiseSegment], capture: NoiseCaptureRecorder.CaptureInfo, amps: [Float]) -> some View {
        let maxLayer = segs.map(\.layer).max() ?? 0
        let totalDur = appState.audioPlayer.duration > 0
            ? appState.audioPlayer.duration
            : max(1, Double(amps.count) * 0.3)

        return VStack(spacing: 1) {
            ForEach(0...maxLayer, id: \.self) { layerIdx in
                let layerSegs = segs.filter { $0.layer == layerIdx }
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        ForEach(layerSegs) { seg in
                            let t0 = seg.timestamp.timeIntervalSince(capture.date)
                            let t1 = seg.endTime.timeIntervalSince(capture.date)
                            let x = max(0, t0 / totalDur * w)
                            let segW = max(28, min(w - x, (t1 - t0) / totalDur * w))
                            let typeLabel = NoiseTypeLabel(rawValue: seg.noiseType) ?? .unknown

                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 1).fill(noiseColor(seg.noiseType)).frame(width: 3)
                                Text(typeLabel.displayName)
                                    .font(.system(size: 9)).foregroundStyle(AppColors.textSecondary).lineLimit(1)
                                if seg.isConfirmed {
                                    Image(systemName: "checkmark").font(.system(size: 7)).foregroundStyle(AppColors.success)
                                }
                            }
                            .frame(width: segW, height: 14, alignment: .leading)
                            .background(noiseColor(seg.noiseType).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .offset(x: x)
                            .onTapGesture { editingSegment = seg }
                        }
                    }
                }
                .frame(height: 16)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
    }

    private func confirmBar(capture: NoiseCaptureRecorder.CaptureInfo, segs: [NoiseSegment]) -> some View {
        let unconfirmed = segs.filter { !$0.isConfirmed }
        return Group {
            if !unconfirmed.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        Task { await confirmAll(capture: capture) }
                    } label: {
                        Label(L10n.confirmAllNoise, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.success)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(AppColors.success.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.cardPadding).padding(.vertical, 4)
            }
        }
    }

    private func confirmAll(capture: NoiseCaptureRecorder.CaptureInfo) async {
        guard var segs = segCache[capture.id] else { return }
        let context = appState.persistence.newBackgroundContext()
        for i in segs.indices where !segs[i].isConfirmed {
            segs[i].isConfirmed = true
            let predicate = #Predicate<SDNoiseSegment> { $0.id == segs[i].id }
            if let sd = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
                sd.isConfirmed = true
            }
            appState.mlRetrainer.addConfirmedSample(
                noiseType: segs[i].displayType,
                features: ["rms_energy": pow(10, segs[i].energyDB / 20)]
            )
        }
        try? context.save()
        await MainActor.run {
            segCache[capture.id] = segs
            for seg in segs {
                if let idx = segments.firstIndex(where: { $0.id == seg.id }) { segments[idx] = seg }
            }
        }
    }

    // MARK: - Playback

    private func playbackBar(capture: NoiseCaptureRecorder.CaptureInfo) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                guard let url = appState.noiseCaptureRecorder.audioURL(for: capture.directoryURL) else { return }
                if appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == capture.id {
                    appState.audioPlayer.stop()
                } else {
                    appState.audioPlayer.play(url: url, eventId: capture.id)
                }
            } label: {
                Image(systemName: appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == capture.id
                      ? "pause.fill" : "play.fill")
                    .font(.system(size: 12)).foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)

            if appState.audioPlayer.playingEventId == capture.id {
                Text(DurationFormatter.format(appState.audioPlayer.currentTime, style: .compact))
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(AppColors.textTertiary)
                Slider(value: Binding(
                    get: { appState.audioPlayer.duration > 0 ? appState.audioPlayer.currentTime / appState.audioPlayer.duration : 0 },
                    set: { appState.audioPlayer.seek(to: $0 * appState.audioPlayer.duration) }
                ), in: 0...1)
                .tint(AppColors.primary).controlSize(.mini)
                Text(DurationFormatter.format(appState.audioPlayer.duration, style: .compact))
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(AppColors.textTertiary)
            } else {
                Spacer()
                let segs = segCache[capture.id] ?? []
                if !segs.isEmpty {
                    Text("\(segs.count) events").font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding).padding(.vertical, 6)
    }

    // MARK: - Summary Badges

    private func noiseSummaryBadges(_ segs: [NoiseSegment]) -> some View {
        let typeCounts = Dictionary(grouping: segs, by: \.noiseType).mapValues(\.count)
        let sorted = typeCounts.sorted { $0.value > $1.value }.prefix(3)
        return HStack(spacing: 3) {
            ForEach(sorted, id: \.key) { type, count in
                HStack(spacing: 2) {
                    Circle().fill(noiseColor(type)).frame(width: 5, height: 5)
                    Text("\(count)").font(.system(size: 9)).foregroundStyle(AppColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Manual Annotation

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
                Button(L10n.cancel) {
                    showManualTypePicker = false
                    manualSelectStart = nil; manualSelectEnd = nil; manualSelectCaptureId = nil
                }
                .buttonStyle(.bordered)
                Button(L10n.confirmEvent) {
                    addManualSegment()
                    showManualTypePicker = false
                }
                .buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
        }
        .padding(AppSpacing.xl).frame(width: 350, height: 180)
    }

    private func addManualSegment() {
        guard let captureId = manualSelectCaptureId,
              let s = manualSelectStart, let e = manualSelectEnd,
              let cap = captures.first(where: { $0.id == captureId }) else { return }
        let amps = ampCache[captureId] ?? []
        let totalDur = appState.audioPlayer.duration > 0
            ? appState.audioPlayer.duration
            : max(1, Double(amps.count) * 0.3)
        let baseW = max(700, CGFloat(amps.count)) * zoomScale
        let t0 = Double(min(s, e)) / Double(baseW) * totalDur
        let t1 = Double(max(s, e)) / Double(baseW) * totalDur

        let seg = NoiseSegment(
            sessionId: captureId,
            timestamp: cap.date.addingTimeInterval(t0),
            endTime: cap.date.addingTimeInterval(t1),
            noiseType: manualTypeName, confidence: 1.0, energyDB: 0, layer: 0
        )

        let context = appState.persistence.newBackgroundContext()
        context.insert(SDNoiseSegment(
            id: seg.id, sessionId: seg.sessionId, timestamp: seg.timestamp,
            endTime: seg.endTime, noiseType: seg.noiseType, confidence: seg.confidence,
            energyDB: seg.energyDB, layer: seg.layer
        ))
        try? context.save()

        segments.append(seg)
        segCache[captureId, default: []].append(seg)

        if let clipURL = appState.noiseCaptureRecorder.extractClip(
            from: cap.directoryURL, startTime: t0, endTime: t1, clipId: seg.id
        ) {
            appState.noiseTypeManager.addSoundClip(to: manualTypeName, url: clipURL)
        }

        manualSelectStart = nil; manualSelectEnd = nil; manualSelectCaptureId = nil
    }

    // MARK: - Helpers

    private func noiseColor(_ type: String) -> Color {
        Color(hex: appState.noiseTypeManager.colorHex(for: type))
    }

    private func formatSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        return mb >= 1 ? String(format: "%.1f MB", mb) : String(format: "%.0f KB", Double(bytes) / 1024)
    }

    private func updateSegmentInCache(_ seg: NoiseSegment) {
        if var list = segCache[seg.sessionId], let idx = list.firstIndex(where: { $0.id == seg.id }) {
            list[idx] = seg
            segCache[seg.sessionId] = list
        }
        if let idx = segments.firstIndex(where: { $0.id == seg.id }) {
            segments[idx] = seg
        }
    }

    // MARK: - Capture

    private func startCapture() {
        isCapturing = true
        captureTask = Task {
            do {
                if !appState.micPermissionGranted { await appState.requestMicPermission() }
                guard appState.micPermissionGranted else { return }
                let captureId = try appState.noiseCaptureRecorder.startCapture()
                try await appState.captureService.startCapture()
                let separator = NoiseSeparatorBridge()
                let stream = appState.captureService.audioStream
                var segStart = Date()

                for await frame in stream {
                    guard isCapturing else { break }
                    appState.noiseCaptureRecorder.feedAudio(frame.samples)
                    separator.updateNoiseFloor(samples: frame.samples)
                    let layers = separator.decomposeMultiLayer(samples: frame.samples)
                    let bands = separator.computeBandEnergy(samples: frame.samples)
                    let db = bands.totalRMS > 0 ? 20.0 * log10(Double(bands.totalRMS)) : -100
                    await MainActor.run {
                        liveNoiseType = layers.first?.type.rawValue ?? "quiet"
                        liveDB = db
                    }

                    let now = Date()
                    if now.timeIntervalSince(segStart) > 2 && !layers.isEmpty {
                        let context = appState.persistence.newBackgroundContext()
                        for (layerIdx, layer) in layers.enumerated() {
                            let seg = NoiseSegment(
                                sessionId: captureId, timestamp: segStart, endTime: now,
                                noiseType: layer.type.rawValue, confidence: Double(layer.confidence),
                                energyDB: Double(layer.energy > 0 ? 20 * log10(layer.energy) : -100),
                                layer: layerIdx
                            )
                            context.insert(SDNoiseSegment(
                                id: seg.id, sessionId: seg.sessionId, timestamp: seg.timestamp,
                                endTime: seg.endTime, noiseType: seg.noiseType, confidence: seg.confidence,
                                energyDB: seg.energyDB, layer: layerIdx
                            ))
                            await MainActor.run {
                                segments.append(seg)
                                segCache[captureId, default: []].append(seg)
                            }
                        }
                        try? context.save()
                        segStart = now
                    } else if layers.isEmpty {
                        segStart = Date()
                    }
                }
            } catch {}
            appState.captureService.stopCapture()
            appState.noiseCaptureRecorder.stopCapture()
            await MainActor.run {
                isCapturing = false
                captures = appState.noiseCaptureRecorder.allCaptures()
            }
        }
    }

    private func stopCapture() {
        isCapturing = false
        captureTask?.cancel()
        captureTask = nil
    }

    // MARK: - Data

    private func loadAllSegments() async {
        let context = appState.persistence.newBackgroundContext()
        let descriptor = FetchDescriptor<SDNoiseSegment>(sortBy: [SortDescriptor(\.timestamp)])
        let all = (try? context.fetch(descriptor)) ?? []
        var bySession: [UUID: [NoiseSegment]] = [:]
        var flat: [NoiseSegment] = []
        for sd in all {
            let seg = NoiseSegment(
                id: sd.id, sessionId: sd.sessionId, timestamp: sd.timestamp,
                endTime: sd.endTime, noiseType: sd.noiseType, confidence: sd.confidence,
                energyDB: sd.energyDB, audioClipURL: sd.audioClipPath.flatMap { URL(fileURLWithPath: $0) },
                isConfirmed: sd.isConfirmed, userLabel: sd.userLabel
            )
            bySession[sd.sessionId, default: []].append(seg)
            flat.append(seg)
        }
        await MainActor.run {
            segments = flat
            segCache = bySession
        }
    }

    private func saveAndRetrain(_ seg: NoiseSegment) async {
        let context = appState.persistence.newBackgroundContext()
        let predicate = #Predicate<SDNoiseSegment> { $0.id == seg.id }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.noiseType = seg.noiseType
            existing.isConfirmed = seg.isConfirmed
            existing.userLabel = seg.userLabel
            try? context.save()
        }
        if seg.isConfirmed {
            appState.mlRetrainer.addConfirmedSample(
                noiseType: seg.displayType,
                features: ["rms_energy": pow(10, seg.energyDB / 20)]
            )
        }
    }
}

// MARK: - Editor

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
