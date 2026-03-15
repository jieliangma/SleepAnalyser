import SwiftUI
import Charts

struct AudioRecordingsView: View {
    @Environment(AppState.self) private var appState
    @State private var recordings: [(sessionId: String, url: URL, size: Int64, date: Date)] = []
    @State private var selectedRecording: URL?
    @State private var selectedSessionId: String?
    @State private var events: [AudioEvent] = []
    @State private var showEventEditor = false
    @State private var editingEvent: AudioEvent?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                HStack {
                    Text(L10n.recordings).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                    Spacer()
                }

                if let selectedRecording, let selectedSessionId {
                    playerSection(url: selectedRecording, sessionId: selectedSessionId)
                }

                if recordings.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "waveform").font(.system(size: 48)).foregroundStyle(AppColors.textTertiary)
                        Text(L10n.noRecordings).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(recordings, id: \.url) { rec in
                        recordingCard(rec)
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .task {
            recordings = appState.recordingManager.allRecordings()
        }
        .sheet(isPresented: $showEventEditor) {
            if let editingEvent {
                EventEditorView(event: editingEvent, allEvents: $events)
            }
        }
    }

    private func recordingCard(_ rec: (sessionId: String, url: URL, size: Int64, date: Date)) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 28)).foregroundStyle(AppColors.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.date, style: .date).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Text(formatSize(rec.size)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
            Button {
                selectedRecording = rec.url
                selectedSessionId = rec.sessionId
                Task {
                    if let uuid = UUID(uuidString: rec.sessionId) {
                        events = (try? await appState.sessionRepo.getEvents(forSession: uuid)) ?? []
                    }
                }
            } label: {
                Image(systemName: selectedRecording == rec.url ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24)).foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)
            Button {
                appState.recordingManager.deleteClip(at: rec.url)
                recordings = appState.recordingManager.allRecordings()
                if selectedRecording == rec.url { selectedRecording = nil }
            } label: {
                Image(systemName: "trash").font(.system(size: 14)).foregroundStyle(AppColors.error.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private func playerSection(url: URL, sessionId: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            waveformView
            playbackControls(url: url)
            if !events.isEmpty { eventMarkersSection }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private var waveformView: some View {
        let amplitudes = appState.recordingManager.nightAmplitudes
        return Canvas { context, size in
            let w = size.width
            let h = size.height
            let midY = h / 2
            guard !amplitudes.isEmpty else { return }
            let step = w / Double(amplitudes.count)
            var path = Path()
            for (i, amp) in amplitudes.enumerated() {
                let x = Double(i) * step
                let barH = Double(amp) * h * 3
                path.addRect(CGRect(x: x, y: midY - barH / 2, width: max(step - 0.5, 0.5), height: max(barH, 0.5)))
            }
            context.fill(path, with: .color(AppColors.primary.opacity(0.6)))

            if appState.audioPlayer.isPlaying && appState.audioPlayer.duration > 0 {
                let progress = appState.audioPlayer.currentTime / appState.audioPlayer.duration
                let cursorX = progress * w
                var cursor = Path()
                cursor.move(to: CGPoint(x: cursorX, y: 0))
                cursor.addLine(to: CGPoint(x: cursorX, y: h))
                context.stroke(cursor, with: .color(AppColors.error), lineWidth: 1.5)
            }

            for event in events {
                if let sessionStart = appState.activeSession?.startAt, appState.audioPlayer.duration > 0 {
                    let offset = event.startAt.timeIntervalSince(sessionStart)
                    let x = (offset / appState.audioPlayer.duration) * w
                    let markerRect = CGRect(x: x - 1, y: 0, width: 2, height: h)
                    context.fill(Path(markerRect), with: .color(AppColors.warning.opacity(0.8)))
                }
            }
        }
        .frame(height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture { location in
            guard appState.audioPlayer.duration > 0 else { return }
        }
    }

    private func playbackControls(url: URL) -> some View {
        HStack {
            Text(DurationFormatter.format(appState.audioPlayer.currentTime, style: .compact))
                .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary).frame(width: 50)
            Button {
                appState.audioPlayer.toggle(url: url)
            } label: {
                Image(systemName: appState.audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32)).foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)
            Text(DurationFormatter.format(appState.audioPlayer.duration, style: .compact))
                .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary).frame(width: 50)
        }
    }

    private var eventMarkersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(L10n.events).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            ForEach(events) { event in
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: event.eventType.sfSymbolName)
                        .foregroundStyle(AppColors.stageColor(event.isConfirmed ? .n2 : .awake))
                        .frame(width: 20)
                    Text(event.eventType.displayName).font(AppTypography.body).foregroundStyle(AppColors.textPrimary)
                    Text(event.startAt, style: .time).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    if event.isConfirmed {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.success).font(.system(size: 14))
                    }
                    if event.hasAudioClip {
                        Button {
                            if let url = event.audioClipURL {
                                appState.audioPlayer.toggle(url: url, eventId: event.id)
                            }
                        } label: {
                            Image(systemName: appState.audioPlayer.playingEventId == event.id ? "stop.circle" : "play.circle")
                                .foregroundStyle(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        editingEvent = event
                        showEventEditor = true
                    } label: {
                        Image(systemName: "pencil.circle").foregroundStyle(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        return mb >= 1 ? String(format: "%.1f MB", mb) : String(format: "%.0f KB", Double(bytes) / 1024)
    }
}
