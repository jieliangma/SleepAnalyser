import SwiftUI
import AppKit

struct EventTimelineView: View {
    let events: [AudioEvent]
    var onTap: ((AudioEvent) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(events) { event in
                    eventCard(event)
                        .onHover { hovering in
                            if hovering && event.hasAudioClip {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                        .onTapGesture {
                            if event.hasAudioClip { onTap?(event) }
                        }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.visible)
        .frame(minHeight: 70)
    }

    private func eventCard(_ event: AudioEvent) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: event.eventType.sfSymbolName)
                .font(.system(size: 16))
                .foregroundStyle(severityColor(event.severity))
            Text(event.eventType.displayName)
                .font(.system(size: 10)).foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
            Text(event.startAt, style: .time)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
            if event.hasAudioClip {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.primary)
            }
        }
        .frame(minWidth: 72)
        .padding(AppSpacing.sm)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func severityColor(_ severity: Double) -> Color {
        switch severity {
        case 0.7...1.0: return AppColors.error
        case 0.4..<0.7: return AppColors.warning
        default: return AppColors.textSecondary
        }
    }
}
