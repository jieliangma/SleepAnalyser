import SwiftUI
import SwiftData
import AVFoundation

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
    @State private var zoomScales: [UUID: CGFloat] = [:]
    @State private var toolMode: [UUID: WaveformTool] = [:]
    @State private var commandKeyDown = false
    @State private var commandMonitor: Any?
    @State private var hoveredCardId: UUID?
    @State private var hoveredWaveformId: UUID?
    @State private var panAccumulated: [UUID: CGFloat] = [:]
    @State private var panDragBase: [UUID: CGFloat] = [:]
    @State private var isDragging: [UUID: Bool] = [:]
    @State private var cursorMonitor: Any?

    private static let zoomKey    = "noiseTraining.zoomScales"
    private static let panKey     = "noiseTraining.panAccumulated"
    private static let toolKey    = "noiseTraining.toolMode"

    enum WaveformTool { case select, pan }
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
            loadPersistedUIState()
            commandMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
                let cmd = event.modifierFlags.contains(.command)
                if cmd != commandKeyDown {
                    DispatchQueue.main.async {
                        commandKeyDown = cmd
                        updateCursorForCurrentState()
                    }
                }
                return event
            }
            cursorMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { event in
                if hoveredWaveformId != nil {
                    updateCursorForCurrentState()
                }
                return event
            }
        }
        .onDisappear {
            if let commandMonitor { NSEvent.removeMonitor(commandMonitor) }
            if let cursorMonitor { NSEvent.removeMonitor(cursorMonitor) }
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
                        let barColor = barSeg.map { noiseColor($0.noiseType).opacity(0.75) }
                            ?? AppColors.primary.opacity(0.4)
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
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 6) {
                        ForEach(uniqueTypes, id: \.self) { type in
                            let typeLabel = NoiseTypeLabel(rawValue: type) ?? .unknown
                            HStack(spacing: 3) {
                                Circle().fill(noiseColor(type)).frame(width: 6, height: 6)
                                Text(typeLabel.displayName)
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

    // MARK: - Per-Capture Card

    private func captureCard(_ cap: NoiseCaptureRecorder.CaptureInfo) -> some View {
        let segs = segCache[cap.id] ?? []
        let amps = ampCache[cap.id] ?? []
        let isThisPlaying = appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == cap.id
        let duration = cap.duration > 0 ? cap.duration : captureDuration(cap)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Text(captureDateString(cap.date))
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Text(DurationFormatter.format(isThisPlaying ? appState.audioPlayer.currentTime : duration, style: .compact))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColors.textTertiary)
                Text(formatSize(cap.size)).font(.system(size: 11)).foregroundStyle(AppColors.textTertiary)
                Button {
                    guard let url = appState.noiseCaptureRecorder.audioURL(for: cap.directoryURL) else { return }
                    if isThisPlaying { appState.audioPlayer.stop() } else { appState.audioPlayer.play(url: url, eventId: cap.id) }
                } label: {
                    Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11)).foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
                HStack(spacing: 0) {
                    Button {
                        toolMode[cap.id] = .select
                        saveUIState()
                    } label: {
                        Image(systemName: "text.cursor")
                            .font(.system(size: 11))
                            .padding(4)
                            .background(toolMode[cap.id] == .select ? AppColors.primary.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(toolMode[cap.id] == .select ? AppColors.primary : AppColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    Button {
                        toolMode[cap.id] = .pan
                        saveUIState()
                    } label: {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 11))
                            .padding(4)
                            .background(toolMode[cap.id] == .pan ? AppColors.primary.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(toolMode[cap.id] == .pan ? AppColors.primary : AppColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .opacity(commandKeyDown && hoveredCardId == cap.id ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: commandKeyDown && hoveredCardId == cap.id)
                Spacer()
                if !segs.isEmpty { noiseSummaryBadges(segs) }
                Button { Task { await reanalyzeCapture(cap) } } label: {
                    Image(systemName: "arrow.trianglehead.2.clockwise").font(.system(size: 12)).foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
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
            labelsAndConfirmRow(segs: segs, capture: cap, amps: amps)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .onHover { inside in
            hoveredCardId = inside ? cap.id : nil
        }
        .onAppear {
            if ampCache[cap.id] == nil {
                ampCache[cap.id] = appState.noiseCaptureRecorder.loadAmplitudes(from: cap.directoryURL)
            }
        }
    }

    // MARK: - Waveform

    private func waveformView(amps: [Float], segs: [NoiseSegment], capture: NoiseCaptureRecorder.CaptureInfo) -> some View {
        let zoom = zoomScales[capture.id] ?? 1.0
        let panOffset = panAccumulated[capture.id] ?? 0

        return GeometryReader { geo in
            let baseW = geo.size.width
            let totalW = baseW * zoom
            let maxOffset = max(0, totalW - baseW)
            let clampedOffset = min(max(0, -panOffset), maxOffset)

            Canvas { context, size in
                let h = size.height, midY = h / 2
                guard !amps.isEmpty else { return }

                let maxAmp = amps.max() ?? 1
                let ampScale: Float = maxAmp > 0 ? 1.0 / maxAmp : 1.0
                let totalDur = appState.audioPlayer.duration > 0
                    ? appState.audioPlayer.duration
                    : Double(amps.count) / 15.0

                let visibleStart = clampedOffset / totalW
                let visibleEnd = min(1.0, (clampedOffset + baseW) / totalW)

                let pixelCount = Int(baseW)
                for px in 0..<pixelCount {
                    let normalizedX = visibleStart + Double(px) / Double(pixelCount) * (visibleEnd - visibleStart)
                    let srcIdx = normalizedX * Double(amps.count)
                    let lo = max(0, min(Int(srcIdx), amps.count - 1))
                    let hi = min(lo + 1, amps.count - 1)
                    let frac = Float(srcIdx - Double(lo))
                    let amp = amps[lo] * (1 - frac) + amps[hi] * frac

                    let norm = Double(amp * ampScale)
                    let barH = max(norm * h * 0.92, 0.5)
                    let sampleTime = normalizedX * totalDur
                    let dominantSeg = segs.first { seg in
                        let t0 = seg.timestamp.timeIntervalSince(capture.date)
                        let t1 = seg.endTime.timeIntervalSince(capture.date)
                        return seg.layer == 0 && sampleTime >= t0 && sampleTime < t1
                    }
                    let barColor = dominantSeg.map { noiseColor($0.noiseType).opacity(0.75) }
                        ?? AppColors.primary.opacity(0.45)
                    var p = Path()
                    p.addRect(CGRect(x: Double(px), y: midY - barH / 2, width: 1, height: barH))
                    context.fill(p, with: .color(barColor))
                }

                if appState.audioPlayer.isPlaying && appState.audioPlayer.playingEventId == capture.id && appState.audioPlayer.duration > 0 {
                    let playFraction = appState.audioPlayer.currentTime / appState.audioPlayer.duration
                    let px = (playFraction - visibleStart) / (visibleEnd - visibleStart) * Double(baseW)
                    if px >= 0 && px <= Double(baseW) {
                        var cursor = Path()
                        cursor.move(to: CGPoint(x: px, y: 0))
                        cursor.addLine(to: CGPoint(x: px, y: h))
                        context.stroke(cursor, with: .color(.white), lineWidth: 1)
                    }
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
            .frame(width: baseW, height: 100)
            .contentShape(Rectangle())
            .onHover { inside in
                hoveredWaveformId = inside ? capture.id : nil
                updateCursorForCurrentState()
            }
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { val in
                        if toolMode[capture.id] == .pan {
                            if isDragging[capture.id] != true {
                                isDragging[capture.id] = true
                                panDragBase[capture.id] = panAccumulated[capture.id] ?? 0
                                NSCursor.closedHand.push()
                            }
                            let base = panDragBase[capture.id] ?? 0
                            let newOffset = base + val.translation.width
                            let maxOff = max(0, totalW - baseW)
                            panAccumulated[capture.id] = max(-maxOff, min(0, newOffset))
                        } else {
                            manualSelectCaptureId = capture.id
                            manualSelectStart = val.startLocation.x
                            manualSelectEnd = val.location.x
                        }
                    }
                    .onEnded { val in
                        if toolMode[capture.id] == .pan {
                            isDragging[capture.id] = false
                            NSCursor.pop()
                            saveUIState()
                        } else if manualSelectStart != nil {
                            showManualTypePicker = true
                        }
                    }
            )
            .onTapGesture { loc in
                if manualSelectStart != nil {
                    manualSelectStart = nil; manualSelectEnd = nil; manualSelectCaptureId = nil
                } else if appState.audioPlayer.duration > 0, appState.audioPlayer.playingEventId == capture.id {
                    let visibleStart = clampedOffset / totalW
                    let visibleEnd = min(1.0, (clampedOffset + baseW) / totalW)
                    let fraction = visibleStart + loc.x / baseW * (visibleEnd - visibleStart)
                    appState.audioPlayer.seek(to: fraction * appState.audioPlayer.duration)
                }
            }
            .gesture(MagnificationGesture().onChanged { val in
                zoomScales[capture.id] = max(1.0, min(10.0, val))
                saveUIState()
            })
            .onScrollWheelZoom { delta in
                let current = zoomScales[capture.id] ?? 1.0
                let newZoom = max(1.0, min(10.0, current + delta))
                zoomScales[capture.id] = newZoom
                let newMaxOffset = max(0, baseW * newZoom - baseW)
                let currentPan = panAccumulated[capture.id] ?? 0
                panAccumulated[capture.id] = max(-newMaxOffset, min(0, currentPan))
                saveUIState()
            }
        }
        .frame(height: 100)
        .padding(.horizontal, AppSpacing.cardPadding)
    }

    // MARK: - Label Row

    private func labelsAndConfirmRow(segs: [NoiseSegment], capture: NoiseCaptureRecorder.CaptureInfo, amps: [Float]) -> some View {
        var seen = Set<String>()
        let uniqueTypes = segs.compactMap { seg -> String? in
            guard !seen.contains(seg.noiseType) else { return nil }
            seen.insert(seg.noiseType)
            return seg.noiseType
        }
        let hasUnconfirmed = segs.contains { !$0.isConfirmed }

        return HStack(spacing: 6) {
            ForEach(uniqueTypes, id: \.self) { type in
                let typeLabel = NoiseTypeLabel(rawValue: type) ?? .unknown
                HStack(spacing: 3) {
                    Circle().fill(noiseColor(type)).frame(width: 6, height: 6)
                    Text(typeLabel.displayName).font(.system(size: 10)).foregroundStyle(AppColors.textSecondary).fixedSize()
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(noiseColor(type).opacity(0.08))
                .clipShape(Capsule()).fixedSize()
            }
            Spacer()
            if hasUnconfirmed {
                Button {
                    Task { await confirmAll(capture: capture) }
                } label: {
                    Label(L10n.confirmAllNoise, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.success)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(AppColors.success.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding).padding(.vertical, 6)
    }

    private struct MergedLabel: Identifiable {
        let id: UUID
        let segId: UUID
        let noiseType: String
        let label: String
        let x: Double
        let width: Double
    }

    private func mergeAdjacentLabels(segs: [NoiseSegment], totalDur: Double, totalW: Double, captureDate: Date) -> [MergedLabel] {
        let sorted = segs.sorted { $0.timestamp < $1.timestamp }
        var result: [MergedLabel] = []

        for seg in sorted {
            let t0 = seg.timestamp.timeIntervalSince(captureDate)
            let t1 = seg.endTime.timeIntervalSince(captureDate)
            let x = max(0, t0 / totalDur * totalW)
            let endX = t1 / totalDur * totalW

            if let lastIdx = result.lastIndex(where: { $0.noiseType == seg.noiseType }),
               x - (result[lastIdx].x + result[lastIdx].width) < 30 {
                result[lastIdx] = MergedLabel(
                    id: result[lastIdx].id, segId: result[lastIdx].segId,
                    noiseType: result[lastIdx].noiseType, label: result[lastIdx].label,
                    x: result[lastIdx].x, width: endX - result[lastIdx].x
                )
            } else {
                let typeLabel = NoiseTypeLabel(rawValue: seg.noiseType) ?? .unknown
                result.append(MergedLabel(
                    id: seg.id, segId: seg.id, noiseType: seg.noiseType,
                    label: typeLabel.displayName, x: x, width: max(20, endX - x)
                ))
            }
        }
        return result
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
                features: ["rms_energy": pow(10, segs[i].energyDB / 20)],
                segmentId: segs[i].id
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
        let zoom = zoomScales[captureId] ?? 1.0
        let baseW = max(700, CGFloat(amps.count)) * zoom
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

    // MARK: - Re-analyze

    private func reanalyzeCapture(_ cap: NoiseCaptureRecorder.CaptureInfo) async {
        guard let audioURL = appState.noiseCaptureRecorder.audioURL(for: cap.directoryURL),
              let audioFile = try? AVAudioFile(forReading: audioURL) else { return }

        let captureId = cap.id
        let context = appState.persistence.newBackgroundContext()
        let predicate = #Predicate<SDNoiseSegment> { $0.sessionId == captureId }
        let existing = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        for sd in existing { context.delete(sd) }
        try? context.save()

        let separator = NoiseSeparatorBridge()
        let sr = audioFile.processingFormat.sampleRate
        let frameSize: AVAudioFrameCount = 1024
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameSize)!
        var segStart = cap.date
        var newSegs: [NoiseSegment] = []
        let bgContext = appState.persistence.newBackgroundContext()

        while audioFile.framePosition < audioFile.length {
            do { try audioFile.read(into: buffer, frameCount: frameSize) } catch { break }
            guard let channelData = buffer.floatChannelData else { break }
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))

            separator.updateNoiseFloor(samples: samples)
            let (noiseType, conf) = separator.classifyNoise(samples: samples)
            let elapsed = Double(audioFile.framePosition) / sr
            let frameTime = cap.date.addingTimeInterval(elapsed)

            if noiseType != .quiet && conf > 0.3 && frameTime.timeIntervalSince(segStart) > 0.5 {
                let seg = NoiseSegment(
                    sessionId: cap.id, timestamp: segStart, endTime: frameTime,
                    noiseType: noiseType.rawValue, confidence: Double(conf),
                    energyDB: -30, layer: 0
                )
                bgContext.insert(SDNoiseSegment(
                    id: seg.id, sessionId: seg.sessionId, timestamp: seg.timestamp,
                    endTime: seg.endTime, noiseType: seg.noiseType, confidence: seg.confidence,
                    energyDB: seg.energyDB, layer: 0
                ))
                newSegs.append(seg)
                segStart = frameTime
            } else if noiseType == .quiet {
                segStart = frameTime
            }
        }

        try? bgContext.save()
        await MainActor.run {
            segCache[cap.id] = newSegs
        }
    }

    // MARK: - Helpers

    private func saveUIState() {
        let ud = UserDefaults.standard
        ud.set(Dictionary(uniqueKeysWithValues: zoomScales.map { ($0.key.uuidString, Double($0.value)) }),
               forKey: Self.zoomKey)
        ud.set(Dictionary(uniqueKeysWithValues: panAccumulated.map { ($0.key.uuidString, Double($0.value)) }),
               forKey: Self.panKey)
        ud.set(Dictionary(uniqueKeysWithValues: toolMode.map { ($0.key.uuidString, $0.value == .pan ? "pan" : "select") }),
               forKey: Self.toolKey)
    }

    private func loadPersistedUIState() {
        let ud = UserDefaults.standard
        if let saved = ud.dictionary(forKey: Self.zoomKey) as? [String: Double] {
            zoomScales = Dictionary(uniqueKeysWithValues: saved.compactMap { k, v in
                UUID(uuidString: k).map { ($0, CGFloat(v)) }
            })
        }
        if let saved = ud.dictionary(forKey: Self.panKey) as? [String: Double] {
            panAccumulated = Dictionary(uniqueKeysWithValues: saved.compactMap { k, v in
                UUID(uuidString: k).map { ($0, CGFloat(v)) }
            })
        }
        if let saved = ud.dictionary(forKey: Self.toolKey) as? [String: String] {
            toolMode = Dictionary(uniqueKeysWithValues: saved.compactMap { k, v in
                UUID(uuidString: k).map { ($0, v == "pan" ? WaveformTool.pan : WaveformTool.select) }
            })
        }
    }

    private func updateCursorForCurrentState() {
        guard let waveformId = hoveredWaveformId else {
            NSCursor.arrow.set()
            return
        }
        if isDragging[waveformId] == true {
            return
        }
        if toolMode[waveformId] == .pan {
            NSCursor.openHand.set()
        } else {
            NSCursor.iBeam.set()
        }
    }

    private func captureDateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        let langCode = LanguageManager.shared.effectiveLanguageCode
        fmt.locale = Locale(identifier: langCode)
        return fmt.string(from: date)
    }

    private func captureDuration(_ cap: NoiseCaptureRecorder.CaptureInfo) -> TimeInterval {
        if cap.duration > 0 { return cap.duration }
        if cap.size > 0 { return Double(cap.size) / 4.0 / 16000.0 }
        let amps = ampCache[cap.id] ?? []
        if !amps.isEmpty { return Double(amps.count) / 15.0 }
        return 0
    }

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
                    let (noiseType, conf) = separator.classifyNoise(samples: frame.samples)
                    let bands = separator.computeBandEnergy(samples: frame.samples)
                    let db = bands.totalRMS > 0 ? 20.0 * log10(Double(bands.totalRMS)) : -100
                    await MainActor.run {
                        liveNoiseType = noiseType.rawValue
                        liveDB = db
                    }

                    let now = Date()
                    if noiseType != .quiet && conf > 0.3 && now.timeIntervalSince(segStart) > 0.5 {
                        let seg = NoiseSegment(
                            sessionId: captureId, timestamp: segStart, endTime: now,
                            noiseType: noiseType.rawValue, confidence: Double(conf),
                            energyDB: db, layer: 0
                        )
                        let context = appState.persistence.newBackgroundContext()
                        context.insert(SDNoiseSegment(
                            id: seg.id, sessionId: seg.sessionId, timestamp: seg.timestamp,
                            endTime: seg.endTime, noiseType: seg.noiseType, confidence: seg.confidence,
                            energyDB: seg.energyDB, layer: 0
                        ))
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
                for cap in captures {
                    if ampCache[cap.id] == nil {
                        ampCache[cap.id] = appState.noiseCaptureRecorder.loadAmplitudes(from: cap.directoryURL)
                    }
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
                features: ["rms_energy": pow(10, seg.energyDB / 20)],
                segmentId: seg.id
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
