import SwiftUI

struct EventEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State var event: AudioEvent
    @Binding var allEvents: [AudioEvent]
    @State private var selectedType: EventType
    @State private var userNote: String

    init(event: AudioEvent, allEvents: Binding<[AudioEvent]>) {
        self._event = State(initialValue: event)
        self._allEvents = allEvents
        self._selectedType = State(initialValue: event.eventType)
        self._userNote = State(initialValue: event.userLabel ?? "")
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(L10n.editEvent).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)

            if event.hasAudioClip, let url = event.audioClipURL {
                audioPreview(url: url)
            }

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(L10n.eventTypeLabel).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                Picker(L10n.eventTypeLabel, selection: $selectedType) {
                    ForEach(EventType.allCases) { type in
                        Label(type.displayName, systemImage: type.sfSymbolName).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding(AppSpacing.cardPadding).background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(L10n.noteLabel).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                TextField(L10n.notePlaceholder, text: $userNote)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(AppSpacing.cardPadding).background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))

            HStack(spacing: AppSpacing.sm) {
                Text(event.startAt, style: .time).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                Text("→")
                Text(event.endAt, style: .time).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                Spacer()
                ConfidenceBadgeView(level: event.confidenceLevel)
            }

            HStack(spacing: AppSpacing.md) {
                Button(L10n.cancel) { dismiss() }.buttonStyle(.bordered)
                Button(L10n.confirmEvent) {
                    saveEvent()
                    dismiss()
                }
                .buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
        }
        .padding(AppSpacing.xl)
        .frame(minWidth: 400, minHeight: 350)
    }

    private func audioPreview(url: URL) -> some View {
        HStack {
            Button {
                appState.audioPlayer.toggle(url: url, eventId: event.id)
            } label: {
                Image(systemName: appState.audioPlayer.playingEventId == event.id ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28)).foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)

            if appState.audioPlayer.playingEventId == event.id {
                ProgressView(value: appState.audioPlayer.duration > 0 ? appState.audioPlayer.currentTime / appState.audioPlayer.duration : 0)
                    .tint(AppColors.primary)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(AppColors.surfaceLight).frame(height: 4)
            }
        }
        .padding(AppSpacing.cardPadding).background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private func saveEvent() {
        event.eventType = selectedType
        event.userLabel = userNote.isEmpty ? nil : userNote
        event.isConfirmed = true

        if let idx = allEvents.firstIndex(where: { $0.id == event.id }) {
            allEvents[idx] = event
        }

        Task {
            try? await appState.sessionRepo.addEvent(event, toSession: event.sessionId)
        }
    }
}

extension EventType: Identifiable {
    var id: String { rawValue }
}
