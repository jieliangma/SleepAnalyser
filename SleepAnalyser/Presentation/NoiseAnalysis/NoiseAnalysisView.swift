import SwiftUI
import SwiftData

struct NoiseAnalysisView: View {
    @Environment(AppState.self) private var appState
    @State private var segments: [NoiseSegment] = []
    @State private var editingSegment: NoiseSegment?
    @State private var filterType: String = "all"
    @State private var isCapturing = false
    @State private var liveNoiseType: String = "unknown"
    @State private var liveDB: Double = -50
    @State private var captureTask: Task<Void, Never>?
    @State private var captures: [NoiseCaptureRecorder.CaptureInfo] = []
    @State private var selectedCapture: NoiseCaptureRecorder.CaptureInfo?
    @State private var waveformAmps: [Float] = []

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                captureControls
                if let sel = selectedCapture { waveformPlayer(sel) }
                filterBar
                segmentsList
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .task {
            captures = appState.noiseCaptureRecorder.allCaptures()
            await loadSegments()
        }
        .sheet(item: $editingSegment) { seg in
            NoiseSegmentEditorView(segment: seg, onSave: { updated in
                if let idx = segments.firstIndex(where: { $0.id == updated.id }) { segments[idx] = updated }
                Task { await saveAndRetrain(updated) }
            })
        }
    }

    private var captureControls: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Text(L10n.noiseAnalysis).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                Spacer()
                if isCapturing {
                    HStack(spacing: 4) {
                        Circle().fill(AppColors.error).frame(width: 6, height: 6)
                        Text(L10n.recording).font(AppTypography.caption).foregroundStyle(AppColors.error)
                        Text((NoiseTypeLabel(rawValue: liveNoiseType) ?? .unknown).displayName)
                            .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                        Text(String(format: "%.0f dB", liveDB))
                            .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            HStack(spacing: AppSpacing.md) {
                Button {
                    if isCapturing { stopCapture() } else { startCapture() }
                } label: {
                    Label(isCapturing ? L10n.stopCapture : L10n.startCapture,
                          systemImage: isCapturing ? "stop.fill" : "mic.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isCapturing ? .white : AppColors.primary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(isCapturing ? AppColors.error : AppColors.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if !captures.isEmpty {
                    Picker(L10n.recordings, selection: $selectedCapture) {
                        Text("—").tag(NoiseCaptureRecorder.CaptureInfo?.none)
                        ForEach(captures) { cap in
                            Text(cap.date, style: .date).tag(NoiseCaptureRecorder.CaptureInfo?.some(cap))
                        }
                    }
                    .frame(width: 200)
                    .onChange(of: selectedCapture) { _, cap in
                        if let cap { waveformAmps = appState.noiseCaptureRecorder.loadAmplitudes(from: cap.directoryURL) }
                        else { waveformAmps = [] }
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding).background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private func waveformPlayer(_ capture: NoiseCaptureRecorder.CaptureInfo) -> some View {
        VStack(spacing: AppSpacing.sm) {
            waveformCanvas(capture)
            playbackBar(capture)
        }
        .padding(AppSpacing.cardPadding).background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private func waveformCanvas(_ capture: NoiseCaptureRecorder.CaptureInfo) -> some View {
        GeometryReader { geo in
            Canvas { context, size in
                let w = size.width, h = size.height, midY = h / 2
                guard !waveformAmps.isEmpty else { return }
                let step = w / Double(waveformAmps.count)

                let captureStart = capture.date
                let totalDur = appState.audioPlayer.duration > 0 ? appState.audioPlayer.duration : Double(waveformAmps.count) * 0.3

                for seg in segments {
                    let segStartOffset = seg.timestamp.timeIntervalSince(captureStart)
                    let segEndOffset = seg.endTime.timeIntervalSince(captureStart)
                    guard segEndOffset > 0, segStartOffset < totalDur else { continue }
                    let x1 = max(0, segStartOffset / totalDur * w)
                    let x2 = min(w, segEndOffset / totalDur * w)
                    let color = noiseColor(seg.noiseType)
                    context.fill(Path(CGRect(x: x1, y: 0, width: x2 - x1, height: h)), with: .color(color.opacity(0.15)))
                }

                var path = Path()
                for (i, amp) in waveformAmps.enumerated() {
                    let x = Double(i) * step
                    let barH = Double(amp) * h * 4
                    path.addRect(CGRect(x: x, y: midY - barH / 2, width: max(step - 0.3, 0.3), height: max(barH, 0.5)))
                }
                context.fill(path, with: .color(AppColors.primary.opacity(0.5)))

                if appState.audioPlayer.isPlaying && appState.audioPlayer.duration > 0 {
                    let progress = appState.audioPlayer.currentTime / appState.audioPlayer.duration
                    var cursor = Path()
                    cursor.move(to: CGPoint(x: progress * w, y: 0))
                    cursor.addLine(to: CGPoint(x: progress * w, y: h))
                    context.stroke(cursor, with: .color(AppColors.error), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard appState.audioPlayer.duration > 0 else { return }
                let fraction = location.x / geo.size.width
                appState.audioPlayer.seek(to: fraction * appState.audioPlayer.duration)
            }
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func playbackBar(_ capture: NoiseCaptureRecorder.CaptureInfo) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(DurationFormatter.format(appState.audioPlayer.currentTime, style: .compact))
                .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary).frame(width: 50)

            Button {
                guard let url = appState.noiseCaptureRecorder.audioURL(for: capture.directoryURL) else { return }
                if appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == capture.id {
                    appState.audioPlayer.stop()
                } else {
                    appState.audioPlayer.play(url: url, eventId: capture.id)
                }
            } label: {
                Image(systemName: appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == capture.id ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28)).foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)

            Slider(value: Binding(
                get: { appState.audioPlayer.duration > 0 ? appState.audioPlayer.currentTime / appState.audioPlayer.duration : 0 },
                set: { appState.audioPlayer.seek(to: $0 * appState.audioPlayer.duration) }
            ), in: 0...1)
            .tint(AppColors.primary)

            Text(DurationFormatter.format(appState.audioPlayer.duration, style: .compact))
                .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary).frame(width: 50)

            Button {
                appState.noiseCaptureRecorder.deleteCapture(capture)
                captures = appState.noiseCaptureRecorder.allCaptures()
                selectedCapture = nil
                waveformAmps = []
            } label: {
                Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(AppColors.error.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                filterChip("all", L10n.noiseFilterAll)
                ForEach(NoiseTypeLabel.allCases, id: \.rawValue) { type in
                    filterChip(type.rawValue, type.displayName)
                }
            }
        }
    }

    private func filterChip(_ value: String, _ label: String) -> some View {
        Button {
            filterType = value
        } label: {
            Text(label)
                .font(.system(size: 12, weight: filterType == value ? .semibold : .regular))
                .foregroundStyle(filterType == value ? .white : AppColors.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(filterType == value ? AppColors.primary : AppColors.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var filteredSegments: [NoiseSegment] {
        if filterType == "all" { return segments }
        return segments.filter { $0.noiseType == filterType }
    }

    private var segmentsList: some View {
        LazyVStack(spacing: AppSpacing.sm) {
            ForEach(filteredSegments) { seg in segmentCard(seg) }
        }
    }

    private func segmentCard(_ seg: NoiseSegment) -> some View {
        let typeLabel = NoiseTypeLabel(rawValue: seg.noiseType) ?? .unknown
        return HStack(spacing: AppSpacing.md) {
            RoundedRectangle(cornerRadius: 2).fill(noiseColor(seg.noiseType)).frame(width: 4, height: 36)
            Image(systemName: typeLabel.sfSymbol).font(.system(size: 18))
                .foregroundStyle(seg.isConfirmed ? AppColors.success : noiseColor(seg.noiseType)).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.sm) {
                    Text(seg.displayType).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                    if seg.isConfirmed {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 10)).foregroundStyle(AppColors.success)
                    }
                }
                HStack(spacing: AppSpacing.sm) {
                    Text(seg.timestamp, style: .time).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    Text(String(format: "%.1fs", seg.duration)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    Text(String(format: "%.0f dB", seg.energyDB)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                }
            }
            Spacer()
            if let url = seg.audioClipURL {
                Button {
                    appState.audioPlayer.toggle(url: url, eventId: seg.id)
                } label: {
                    Image(systemName: appState.audioPlayer.playingEventId == seg.id ? "stop.circle" : "play.circle")
                        .font(.system(size: 18)).foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
            Button { editingSegment = seg } label: {
                Image(systemName: "pencil.circle").font(.system(size: 16)).foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.cardPadding).padding(.vertical, 8)
        .background(AppColors.surface).clipShape(RoundedRectangle(cornerRadius: 8))
    }

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
                            let clipURL = appState.recordingManager.captureEventClip(
                                eventId: UUID(), eventTime: now, sessionStart: segStart
                            )
                            let seg = NoiseSegment(
                                sessionId: captureId, timestamp: segStart, endTime: now,
                                noiseType: noiseType.rawValue, confidence: Double(conf),
                                energyDB: db, audioClipURL: clipURL
                            )
                            let context = appState.persistence.newBackgroundContext()
                            context.insert(SDNoiseSegment(
                                id: seg.id, sessionId: seg.sessionId, timestamp: seg.timestamp,
                                endTime: seg.endTime, noiseType: seg.noiseType, confidence: seg.confidence,
                                energyDB: seg.energyDB, audioClipPath: clipURL?.path
                            ))
                            try? context.save()
                            await MainActor.run { segments.append(seg) }
                            segStart = now
                        }
                    } else { segStart = Date() }
                }
            } catch {
                await MainActor.run { isCapturing = false }
            }
            appState.captureService.stopCapture()
            appState.noiseCaptureRecorder.stopCapture()
            await MainActor.run {
                captures = appState.noiseCaptureRecorder.allCaptures()
                waveformAmps = appState.noiseCaptureRecorder.amplitudes
            }
        }
    }

    private func stopCapture() {
        isCapturing = false
        captureTask?.cancel()
        captureTask = nil
    }

    private func loadSegments() async {
        let context = appState.persistence.newBackgroundContext()
        let descriptor = FetchDescriptor<SDNoiseSegment>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let sdSegments = (try? context.fetch(descriptor)) ?? []
        await MainActor.run {
            segments = sdSegments.prefix(200).map { sd in
                NoiseSegment(id: sd.id, sessionId: sd.sessionId, timestamp: sd.timestamp,
                             endTime: sd.endTime, noiseType: sd.noiseType, confidence: sd.confidence,
                             energyDB: sd.energyDB, audioClipURL: sd.audioClipPath.flatMap { URL(fileURLWithPath: $0) },
                             isConfirmed: sd.isConfirmed, userLabel: sd.userLabel)
            }
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
            let features: [String: Double] = [
                "spectral_centroid": 0, "spectral_rolloff": 0,
                "spectral_flatness": 0, "zero_crossing_rate": 0,
                "rms_energy": pow(10, seg.energyDB / 20)
            ]
            appState.mlRetrainer.addConfirmedSample(noiseType: seg.displayType, features: features)
        }
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
