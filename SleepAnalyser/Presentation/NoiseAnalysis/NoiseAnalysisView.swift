import SwiftUI
import SwiftData
import AVFoundation

struct NoiseAnalysisView: View {
    @Environment(AppState.self) private var appState
    @State private var isCapturing = false
    @State private var liveNoiseType: String = "unknown"
    @State private var liveDB: Double = -50
    @State private var captureTask: Task<Void, Never>?
    @State private var captures: [NoiseCaptureRecorder.CaptureInfo] = []
    @State private var ampCache: [UUID: [Float]] = [:]
    @State private var segCache: [UUID: [NoiseSegment]] = [:]
    @State private var hoveredCardId: UUID?
    @State private var segments: [NoiseSegment] = []
    @State private var selectedCapture: NoiseCaptureRecorder.CaptureInfo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    if isCapturing { liveWaveform }
                    ForEach(captures) { cap in
                        NavigationLink(value: cap) {
                            captureListCard(cap)
                        }
                        .buttonStyle(.plain)
                    }
                    if captures.isEmpty && !isCapturing { emptyState }
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.background)
            .navigationDestination(for: NoiseCaptureRecorder.CaptureInfo.self) { cap in
                NoiseTrainingDetailView(capture: cap)
                    .environment(appState)
            }
        }
        .task {
            captures = appState.noiseCaptureRecorder.allCaptures()
            await loadAllSegments()
        }
    }

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
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 48)).foregroundStyle(AppColors.textTertiary)
            Text(L10n.noNoiseSegments)
                .font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, 60)
    }

    private var liveWaveform: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                    let h = size.height, midY = h / 2
                    let liveAmps = appState.noiseCaptureRecorder.amplitudes
                    guard !liveAmps.isEmpty else { return }
                    let maxA = liveAmps.max() ?? 1
                    let s: Float = maxA > 0 ? 1.0 / maxA : 1
                    let visibleCount = min(liveAmps.count, Int(size.width))
                    let startIdx = max(0, liveAmps.count - visibleCount)
                    let captureStart = appState.noiseCaptureRecorder.startTime ?? Date()
                    let elapsed = Date().timeIntervalSince(captureStart)
                    let captureId = appState.noiseCaptureRecorder.captureId ?? UUID()
                    let liveSegs = segCache[captureId] ?? []

                    for i in 0..<visibleCount {
                        let amp = liveAmps[startIdx + i]
                        let x = Double(i)
                        let barH = Double(amp * s) * h * 0.9
                        let sampleTime = elapsed > 0 ? Double(startIdx + i) / Double(max(liveAmps.count, 1)) * elapsed : 0
                        let barSeg = liveSegs.first { seg in
                            seg.layer == 0 &&
                            sampleTime >= seg.timestamp.timeIntervalSince(captureStart) &&
                            sampleTime < seg.endTime.timeIntervalSince(captureStart)
                        }
                        let barColor = barSeg.map { noiseColor($0.noiseType).opacity(0.75) } ?? AppColors.primary.opacity(0.4)
                        var p = Path()
                        p.addRect(CGRect(x: x, y: midY - barH / 2, width: 1, height: max(barH, 0.5)))
                        context.fill(p, with: .color(barColor))
                    }
                }
                .frame(height: 80)
            }

            let captureId = appState.noiseCaptureRecorder.captureId ?? UUID()
            let liveSegs = segCache[captureId] ?? []
            if !liveSegs.isEmpty {
                let seen = NSMutableSet()
                let uniqueTypes = liveSegs.compactMap { seg -> String? in
                    guard !seen.contains(seg.noiseType) else { return nil }
                    seen.add(seg.noiseType)
                    return seg.noiseType
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(uniqueTypes, id: \.self) { type in
                            HStack(spacing: 3) {
                                Circle().fill(noiseColor(type)).frame(width: 6, height: 6)
                                Text((NoiseTypeLabel(rawValue: type) ?? .unknown).displayName)
                                    .font(.system(size: 10)).foregroundStyle(AppColors.textSecondary).fixedSize()
                            }
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(noiseColor(type).opacity(0.08))
                            .clipShape(Capsule()).fixedSize()
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

    private func captureListCard(_ cap: NoiseCaptureRecorder.CaptureInfo) -> some View {
        let segs = (segCache[cap.id] ?? []).filter { $0.layer == 0 }
        let dur = cap.duration > 0 ? cap.duration : captureDuration(cap)
        let isHovered = hoveredCardId == cap.id

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(captureDateString(cap.date))
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(DurationFormatter.format(dur, style: .compact))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                summaryBadges(segs)

                Button {
                    if appState.audioPlayer.playingEventId == cap.id { appState.audioPlayer.stop() }
                    appState.noiseCaptureRecorder.deleteCapture(cap)
                    captures = appState.noiseCaptureRecorder.allCaptures()
                    ampCache.removeValue(forKey: cap.id)
                    segCache.removeValue(forKey: cap.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12)).foregroundStyle(AppColors.error.opacity(0.6))
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }

            miniWaveform(cap: cap, segs: segs)
        }
        .padding(AppSpacing.cardPadding)
        .background(isHovered ? AppColors.surface.opacity(0.9) : AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(isHovered ? AppColors.primary.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { hoveredCardId = $0 ? cap.id : nil }
        .onAppear {
            if ampCache[cap.id] == nil {
                ampCache[cap.id] = appState.noiseCaptureRecorder.loadAmplitudes(from: cap.directoryURL)
            }
        }
    }

    private func miniWaveform(cap: NoiseCaptureRecorder.CaptureInfo, segs: [NoiseSegment]) -> some View {
        let amps = ampCache[cap.id] ?? []
        return GeometryReader { geo in
            Canvas { context, size in
                guard !amps.isEmpty else { return }
                let h = size.height, midY = h / 2
                let maxAmp = amps.max() ?? 1
                let scale: Float = maxAmp > 0 ? 1.0 / maxAmp : 1.0
                let totalDur = cap.duration > 0 ? cap.duration : Double(amps.count) / 15.0
                for px in 0..<Int(size.width) {
                    let nx = Double(px) / Double(size.width)
                    let srcIdx = nx * Double(amps.count)
                    let lo = max(0, min(Int(srcIdx), amps.count - 1))
                    let hi = min(lo + 1, amps.count - 1)
                    let frac = Float(srcIdx - Double(lo))
                    let amp = amps[lo] * (1 - frac) + amps[hi] * frac
                    let barH = max(Double(amp * scale) * h * 0.9, 0.5)
                    let t = nx * totalDur
                    let seg = segs.first { s in
                        let t0 = s.timestamp.timeIntervalSince(cap.date)
                        let t1 = s.endTime.timeIntervalSince(cap.date)
                        return t >= t0 && t < t1
                    }
                    let color = seg.map { noiseColor($0.noiseType).opacity(0.7) } ?? AppColors.primary.opacity(0.35)
                    var p = Path()
                    p.addRect(CGRect(x: Double(px), y: midY - barH / 2, width: 1, height: barH))
                    context.fill(p, with: .color(color))
                }
            }
            .frame(width: geo.size.width, height: 50)
        }
        .frame(height: 50)
    }

    private func summaryBadges(_ segs: [NoiseSegment]) -> some View {
        let counts = Dictionary(grouping: segs, by: \.noiseType).mapValues(\.count)
        let sorted = counts.sorted { $0.value > $1.value }.prefix(4)
        return HStack(spacing: 4) {
            ForEach(sorted, id: \.key) { type, count in
                HStack(spacing: 3) {
                    Circle().fill(noiseColor(type)).frame(width: 5, height: 5)
                    Text((NoiseTypeLabel(rawValue: type) ?? .unknown).displayName)
                        .font(.system(size: 9)).foregroundStyle(AppColors.textTertiary)
                    Text("×\(count)").font(.system(size: 9)).foregroundStyle(AppColors.textTertiary)
                }
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(noiseColor(type).opacity(0.08))
                .clipShape(Capsule())
            }
        }
    }

    private func noiseColor(_ type: String) -> Color {
        Color(hex: appState.noiseTypeManager.colorHex(for: type))
    }

    private func captureDateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        fmt.locale = Locale(identifier: LanguageManager.shared.effectiveLanguageCode)
        return fmt.string(from: date)
    }

    private func captureDuration(_ cap: NoiseCaptureRecorder.CaptureInfo) -> TimeInterval {
        if cap.duration > 0 { return cap.duration }
        if cap.size > 0 { return Double(cap.size) / 4.0 / 16000.0 }
        let a = ampCache[cap.id] ?? []
        return a.isEmpty ? 0 : Double(a.count) / 15.0
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

                    let now = Date()
                    if noiseType != .quiet && conf > 0.3 && now.timeIntervalSince(segStart) > 0.5 {
                        let seg = NoiseSegment(sessionId: captureId, timestamp: segStart, endTime: now,
                                               noiseType: noiseType.rawValue, confidence: Double(conf),
                                               energyDB: db, layer: 0)
                        let context = appState.persistence.newBackgroundContext()
                        context.insert(SDNoiseSegment(id: seg.id, sessionId: seg.sessionId,
                                                       timestamp: seg.timestamp, endTime: seg.endTime,
                                                       noiseType: seg.noiseType, confidence: seg.confidence,
                                                       energyDB: seg.energyDB, layer: 0))
                        try? context.save()
                        await MainActor.run {
                            segments.append(seg)
                            segCache[captureId, default: []].append(seg)
                        }
                        segStart = now
                    } else if noiseType == .quiet {
                        segStart = Date()
                    }
                }
            } catch {}
            appState.captureService.stopCapture()
            appState.noiseCaptureRecorder.stopCapture()
            await MainActor.run {
                isCapturing = false
                captures = appState.noiseCaptureRecorder.allCaptures()
                for cap in captures where ampCache[cap.id] == nil {
                    ampCache[cap.id] = appState.noiseCaptureRecorder.loadAmplitudes(from: cap.directoryURL)
                }
            }
            await loadAllSegments()
        }
    }

    private func stopCapture() {
        isCapturing = false
        captureTask?.cancel()
        captureTask = nil
    }

    private func loadAllSegments() async {
        let context = appState.persistence.newBackgroundContext()
        let descriptor = FetchDescriptor<SDNoiseSegment>(sortBy: [SortDescriptor(\.timestamp)])
        let all = (try? context.fetch(descriptor)) ?? []
        var bySession: [UUID: [NoiseSegment]] = [:]
        var flat: [NoiseSegment] = []
        for sd in all {
            let seg = NoiseSegment(id: sd.id, sessionId: sd.sessionId, timestamp: sd.timestamp,
                                   endTime: sd.endTime, noiseType: sd.noiseType, confidence: sd.confidence,
                                   energyDB: sd.energyDB,
                                   audioClipURL: sd.audioClipPath.flatMap { URL(fileURLWithPath: $0) },
                                   isConfirmed: sd.isConfirmed, userLabel: sd.userLabel, layer: sd.layer)
            bySession[sd.sessionId, default: []].append(seg)
            flat.append(seg)
        }
        await MainActor.run { segments = flat; segCache = bySession }
    }
}
