import SwiftUI
import SwiftData

struct NoiseAnalysisView: View {
    @Environment(AppState.self) private var appState
    @State private var segments: [NoiseSegment] = []
    @State private var editingSegment: NoiseSegment?
    @State private var filterType: String = "all"
    @State private var isLiveCapturing = false
    @State private var liveNoiseType: String = "unknown"
    @State private var liveDB: Double = -50
    @State private var captureTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                header
                liveCaptureSection
                filterBar
                if filteredSegments.isEmpty {
                    emptyState
                } else {
                    segmentsList
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .task { await loadSegments() }
        .sheet(item: $editingSegment) { segment in
            NoiseSegmentEditorView(segment: segment, onSave: { updated in
                if let idx = segments.firstIndex(where: { $0.id == updated.id }) {
                    segments[idx] = updated
                }
                Task { await saveSegment(updated) }
            })
        }
    }

    private var header: some View {
        HStack {
            Text(L10n.noiseAnalysis).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
            Spacer()
            Button {
                exportMLTrainingData()
            } label: {
                Label(L10n.exportMLData, systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppColors.primary.opacity(0.1)).clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Text("\(filteredSegments.count)").font(AppTypography.metricValue).foregroundStyle(AppColors.textSecondary)
        }
    }

    private var liveCaptureSection: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Text(L10n.liveCapture).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Spacer()
                if isLiveCapturing {
                    HStack(spacing: 4) {
                        Circle().fill(AppColors.success).frame(width: 6, height: 6)
                        Text((NoiseTypeLabel(rawValue: liveNoiseType) ?? .unknown).displayName)
                            .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                        Text(String(format: "%.0f dB", liveDB))
                            .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            Button {
                if isLiveCapturing { stopLiveCapture() } else { startLiveCapture() }
            } label: {
                Label(isLiveCapturing ? L10n.stopCapture : L10n.startCapture,
                      systemImage: isLiveCapturing ? "stop.fill" : "mic.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isLiveCapturing ? AppColors.error : AppColors.primary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background((isLiveCapturing ? AppColors.error : AppColors.primary).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.cardPadding).background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
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
            ForEach(filteredSegments) { segment in
                segmentCard(segment)
            }
        }
    }

    private func segmentCard(_ seg: NoiseSegment) -> some View {
        let typeLabel = NoiseTypeLabel(rawValue: seg.noiseType) ?? .unknown
        return HStack(spacing: AppSpacing.md) {
            Image(systemName: typeLabel.sfSymbol)
                .font(.system(size: 20))
                .foregroundStyle(seg.isConfirmed ? AppColors.success : AppColors.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.sm) {
                    Text(seg.displayType).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                    if seg.isConfirmed {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(AppColors.success)
                    }
                }
                HStack(spacing: AppSpacing.sm) {
                    Text(seg.timestamp, style: .time).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    Text(String(format: "%.1fs", seg.duration)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    Text(String(format: "%.0f dB", seg.energyDB)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                }
            }

            Spacer()

            if seg.audioClipURL != nil {
                Button {
                    if let url = seg.audioClipURL {
                        appState.audioPlayer.toggle(url: url, eventId: seg.id)
                    }
                } label: {
                    Image(systemName: appState.audioPlayer.playingEventId == seg.id ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 22)).foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
            }

            Button { editingSegment = seg } label: {
                Image(systemName: "pencil.circle").font(.system(size: 18)).foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "waveform.badge.magnifyingglass").font(.system(size: 48)).foregroundStyle(AppColors.textTertiary)
            Text(L10n.noNoiseSegments).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, 60)
    }

    private func loadSegments() async {
        var sessionId = appState.activeSession?.id
        if sessionId == nil, let profileId = appState.activeProfile?.id {
            sessionId = (try? await appState.sessionRepo.getLatestSession(profileId: profileId))?.id
        }
        guard let sessionId else { return }
        let context = appState.persistence.newBackgroundContext()
        let predicate = #Predicate<SDNoiseSegment> { $0.sessionId == sessionId }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.timestamp)])
        let sdSegments = (try? context.fetch(descriptor)) ?? []
        await MainActor.run {
            segments = sdSegments.map { sd in
                NoiseSegment(id: sd.id, sessionId: sd.sessionId, timestamp: sd.timestamp,
                             endTime: sd.endTime, noiseType: sd.noiseType, confidence: sd.confidence,
                             energyDB: sd.energyDB, audioClipURL: sd.audioClipPath.flatMap { URL(fileURLWithPath: $0) },
                             isConfirmed: sd.isConfirmed, userLabel: sd.userLabel)
            }
        }
    }

    private func saveSegment(_ seg: NoiseSegment) async {
        let context = appState.persistence.newBackgroundContext()
        let predicate = #Predicate<SDNoiseSegment> { $0.id == seg.id }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.noiseType = seg.noiseType
            existing.isConfirmed = seg.isConfirmed
            existing.userLabel = seg.userLabel
            try? context.save()
        }
    }

    private func startLiveCapture() {
        isLiveCapturing = true
        captureTask = Task {
            do {
                if !appState.micPermissionGranted { await appState.requestMicPermission() }
                guard appState.micPermissionGranted else { return }
                try await appState.captureService.startCapture()
                let separator = NoiseSeparatorBridge()
                let stream = appState.captureService.audioStream
                var segStart = Date()

                for await frame in stream {
                    guard isLiveCapturing else { break }
                    separator.updateNoiseFloor(samples: frame.samples)
                    let (noiseType, conf) = separator.classifyNoise(samples: frame.samples)
                    let bands = separator.computeBandEnergy(samples: frame.samples)
                    let db = bands.totalRMS > 0 ? 20.0 * log10(Double(bands.totalRMS)) : -100

                    await MainActor.run {
                        liveNoiseType = noiseType.rawValue
                        liveDB = db
                    }

                    if noiseType != .quiet && conf > 0.4 {
                        let now = Date()
                        if now.timeIntervalSince(segStart) > 2 {
                            let seg = NoiseSegment(
                                sessionId: appState.activeSession?.id ?? UUID(),
                                timestamp: segStart, endTime: now,
                                noiseType: noiseType.rawValue, confidence: Double(conf), energyDB: db
                            )
                            let context = appState.persistence.newBackgroundContext()
                            context.insert(SDNoiseSegment(
                                id: seg.id, sessionId: seg.sessionId, timestamp: seg.timestamp,
                                endTime: seg.endTime, noiseType: seg.noiseType, confidence: seg.confidence,
                                energyDB: seg.energyDB
                            ))
                            try? context.save()
                            await MainActor.run { segments.append(seg) }
                            segStart = now
                        }
                    } else {
                        segStart = Date()
                    }
                }
            } catch {
                await MainActor.run { isLiveCapturing = false }
            }
            appState.captureService.stopCapture()
        }
    }

    private func stopLiveCapture() {
        isLiveCapturing = false
        captureTask?.cancel()
        captureTask = nil
        appState.captureService.stopCapture()
    }

    private func exportMLTrainingData() {
        let confirmed = segments.filter { $0.isConfirmed }
        guard !confirmed.isEmpty else { return }

        var csv = "timestamp,noise_type,confidence,energy_db,user_label\n"
        for seg in confirmed {
            let ts = ISO8601DateFormatter().string(from: seg.timestamp)
            csv += "\(ts),\(seg.displayType),\(seg.confidence),\(seg.energyDB),\(seg.userLabel ?? "")\n"
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "noise_training_data.csv"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

struct NoiseSegmentEditorView: View {
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

            HStack(spacing: AppSpacing.sm) {
                Text(segment.timestamp, style: .time).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                Text(String(format: "%.0f dB", segment.energyDB)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }

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
