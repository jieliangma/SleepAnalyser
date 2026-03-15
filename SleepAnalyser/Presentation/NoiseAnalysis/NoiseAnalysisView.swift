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

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                header
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
                Text(formatSize(cap.size)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                Button {
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
            labelRow(segs: segs, capture: cap, amps: amps)
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
        GeometryReader { geo in
            let totalW = max(geo.size.width, geo.size.width * zoomScale)
            ScrollView(.horizontal, showsIndicators: false) {
                Canvas { context, size in
                    let w = size.width, h = size.height, midY = h / 2
                    guard !amps.isEmpty else { return }

                    let maxAmp = amps.max() ?? 1
                    let scale: Float = maxAmp > 0 ? 1.0 / maxAmp : 1.0
                    let totalDur = appState.audioPlayer.duration > 0
                        ? appState.audioPlayer.duration
                        : Double(amps.count) * 0.3

                    for seg in segs {
                        let t0 = seg.timestamp.timeIntervalSince(capture.date)
                        let t1 = seg.endTime.timeIntervalSince(capture.date)
                        guard t1 > 0, t0 < totalDur else { continue }
                        let x1 = max(0, t0 / totalDur * w)
                        let x2 = min(w, t1 / totalDur * w)
                        context.fill(
                            Path(CGRect(x: x1, y: 0, width: x2 - x1, height: h)),
                            with: .color(noiseColor(seg.noiseType).opacity(0.12))
                        )
                    }

                    let pixelW = w / Double(amps.count)
                    var path = Path()
                    for (i, amp) in amps.enumerated() {
                        let x = Double(i) * pixelW
                        let norm = Double(amp * scale)
                        let barH = norm * h * 0.9
                        path.addRect(CGRect(x: x, y: midY - barH / 2, width: max(pixelW, 1), height: max(barH, 0.5)))
                    }
                    context.fill(path, with: .color(AppColors.primary.opacity(0.6)))

                    if appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == capture.id && appState.audioPlayer.duration > 0 {
                        let px = appState.audioPlayer.currentTime / appState.audioPlayer.duration * w
                        var cursor = Path()
                        cursor.move(to: CGPoint(x: px, y: 0))
                        cursor.addLine(to: CGPoint(x: px, y: h))
                        context.stroke(cursor, with: .color(AppColors.error), lineWidth: 1)
                    }
                }
                .frame(width: totalW, height: 90)
                .contentShape(Rectangle())
                .onTapGesture { loc in
                    guard appState.audioPlayer.duration > 0, appState.audioPlayer.playingEventId == capture.id else { return }
                    let frac = loc.x / totalW
                    appState.audioPlayer.seek(to: frac * appState.audioPlayer.duration)
                }
                .gesture(MagnificationGesture().onChanged { val in
                    zoomScale = max(1.0, min(10.0, val))
                })
            }
        }
        .frame(height: 90)
    }

    // MARK: - Label Row

    private func labelRow(segs: [NoiseSegment], capture: NoiseCaptureRecorder.CaptureInfo, amps: [Float]) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let totalDur = appState.audioPlayer.duration > 0
                ? appState.audioPlayer.duration
                : max(1, Double(amps.count) * 0.3)

            ZStack(alignment: .leading) {
                ForEach(segs) { seg in
                    let t0 = seg.timestamp.timeIntervalSince(capture.date)
                    let t1 = seg.endTime.timeIntervalSince(capture.date)
                    let x = max(0, t0 / totalDur * w)
                    let segW = max(30, min(w - x, (t1 - t0) / totalDur * w))
                    let typeLabel = NoiseTypeLabel(rawValue: seg.noiseType) ?? .unknown

                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 1).fill(noiseColor(seg.noiseType)).frame(width: 3)
                        Text(typeLabel.displayName)
                            .font(.system(size: 9)).foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(width: segW, height: 16, alignment: .leading)
                    .offset(x: x)
                    .onTapGesture { editingSegment = seg }
                }
            }
        }
        .frame(height: 20)
        .padding(.horizontal, AppSpacing.cardPadding)
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

    // MARK: - Helpers

    private func noiseColor(_ type: String) -> Color {
        switch type {
        case "traffic", "motorcycle": return AppColors.error
        case "wind", "rain": return Color(hex: "38BDF8")
        case "hvac": return AppColors.warning
        case "speech": return Color(hex: "A855F7")
        case "quiet": return AppColors.success
        default: return AppColors.textTertiary
        }
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
                    let (noiseType, conf) = separator.classifyNoise(samples: frame.samples)
                    let bands = separator.computeBandEnergy(samples: frame.samples)
                    let db = bands.totalRMS > 0 ? 20.0 * log10(Double(bands.totalRMS)) : -100
                    await MainActor.run { liveNoiseType = noiseType.rawValue; liveDB = db }

                    if noiseType != .quiet && conf > 0.4 {
                        let now = Date()
                        if now.timeIntervalSince(segStart) > 2 {
                            let seg = NoiseSegment(
                                sessionId: captureId, timestamp: segStart, endTime: now,
                                noiseType: noiseType.rawValue, confidence: Double(conf), energyDB: db
                            )
                            let context = appState.persistence.newBackgroundContext()
                            context.insert(SDNoiseSegment(
                                id: seg.id, sessionId: seg.sessionId, timestamp: seg.timestamp,
                                endTime: seg.endTime, noiseType: seg.noiseType, confidence: seg.confidence,
                                energyDB: seg.energyDB
                            ))
                            try? context.save()
                            await MainActor.run {
                                segments.append(seg)
                                segCache[captureId, default: []].append(seg)
                            }
                            segStart = now
                        }
                    } else { segStart = Date() }
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
