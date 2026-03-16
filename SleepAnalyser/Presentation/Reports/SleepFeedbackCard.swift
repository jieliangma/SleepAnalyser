import SwiftUI

struct SleepFeedbackCard: View {
    @Environment(AppState.self) private var appState
    let sessionId: UUID
    let epochs: [SleepEpoch]

    @State private var rating: Int = 0
    @State private var showAwakePicker = false
    @State private var selectedEpochIndex: Int? = nil
    @State private var submitted = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("睡眠质量反馈", systemImage: "brain.head.profile")
                .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)

            Text("您的反馈帮助改善睡眠检测精准度")
                .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)

            ratingRow

            awakeCorrectionRow

            if submitted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.success)
                    Text("感谢反馈，已记录").font(AppTypography.caption).foregroundStyle(AppColors.success)
                }
            } else {
                Button {
                    saveAll()
                } label: {
                    Text("提交反馈")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(rating > 0 ? AppColors.primary : AppColors.textTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(rating == 0)
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .onAppear {
            if let existing = appState.feedbackStore.latestRating(for: sessionId) {
                rating = existing
                submitted = true
            }
        }
    }

    private var ratingRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("睡眠感受").font(.system(size: 11)).foregroundStyle(AppColors.textTertiary)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundStyle(star <= rating ? AppColors.warning : AppColors.textTertiary)
                        .onTapGesture { if !submitted { rating = star } }
                }
                if rating > 0 {
                    Text(ratingLabel).font(.system(size: 11)).foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var awakeCorrectionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("标记清醒时段（可选）").font(.system(size: 11)).foregroundStyle(AppColors.textTertiary)
            if epochs.isEmpty {
                Text("无可用时段数据").font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(epochs.enumerated()), id: \.offset) { idx, epoch in
                            let isAwake = epoch.predictedStage == .awake
                            let isSelected = selectedEpochIndex == idx
                            Button {
                                if !submitted {
                                    selectedEpochIndex = isSelected ? nil : idx
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(epoch.timestamp.formatted(.dateTime.hour().minute()))
                                        .font(.system(size: 9))
                                    Text(epoch.predictedStage.displayName)
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(isSelected ? AppColors.warning.opacity(0.2) :
                                            isAwake ? AppColors.error.opacity(0.08) :
                                            AppColors.surfaceLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? AppColors.warning : Color.clear, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                if let idx = selectedEpochIndex {
                    Text("将在 \(epochs[idx].timestamp.formatted(.dateTime.hour().minute())) 标记为清醒")
                        .font(.system(size: 10)).foregroundStyle(AppColors.warning)
                }
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "很差"
        case 2: return "较差"
        case 3: return "一般"
        case 4: return "良好"
        case 5: return "很好"
        default: return ""
        }
    }

    private func saveAll() {
        appState.feedbackStore.addRating(rating, sessionId: sessionId)
        if let idx = selectedEpochIndex {
            appState.feedbackStore.addAwakeCorrection(at: epochs[idx].timestamp)
        }
        submitted = true
    }
}
