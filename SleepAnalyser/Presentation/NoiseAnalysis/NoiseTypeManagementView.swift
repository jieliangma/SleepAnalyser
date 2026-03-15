import SwiftUI

struct NoiseTypeManagementView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddType = false
    @State private var newName = ""
    @State private var newColor = "64748B"
    @State private var newSymbol = "waveform"

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                HStack {
                    Text(L10n.noiseTypes).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Button { showAddType = true } label: {
                        Label(L10n.addRoom, systemImage: "plus.circle.fill")
                            .font(AppTypography.body).foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(appState.noiseTypeManager.types) { config in
                    typeCard(config)
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .sheet(isPresented: $showAddType) { addTypeSheet }
    }

    private func typeCard(_ config: NoiseTypeConfig) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: config.colorHex)).frame(width: 6, height: 36)
                Image(systemName: config.sfSymbol).font(.system(size: 20)).foregroundStyle(Color(hex: config.colorHex))
                    .frame(width: 28)
                Text(config.name).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(config.soundClipURLs.count)").font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                Image(systemName: "speaker.wave.2").font(.system(size: 12)).foregroundStyle(AppColors.textTertiary)

                if !NoiseTypeConfig.builtIn.contains(where: { $0.name == config.name }) {
                    Button {
                        appState.noiseTypeManager.delete(id: config.id)
                    } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(AppColors.error.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !config.soundClipURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(Array(config.soundClipURLs.enumerated()), id: \.offset) { idx, url in
                            HStack(spacing: 4) {
                                Button {
                                    appState.audioPlayer.toggle(url: url)
                                } label: {
                                    Image(systemName: appState.audioPlayer.isPlaying ? "stop.circle" : "play.circle")
                                        .font(.system(size: 14)).foregroundStyle(Color(hex: config.colorHex))
                                }
                                .buttonStyle(.plain)
                                Text(url.lastPathComponent.prefix(12))
                                    .font(.system(size: 9)).foregroundStyle(AppColors.textTertiary).lineLimit(1)
                                Button {
                                    appState.noiseTypeManager.removeSoundClip(from: config.name, at: idx)
                                } label: {
                                    Image(systemName: "xmark.circle").font(.system(size: 10)).foregroundStyle(AppColors.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(4).background(AppColors.surfaceLight).clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding).background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private var addTypeSheet: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(L10n.addNoiseType).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            TextField("Name", text: $newName).textFieldStyle(.roundedBorder).frame(width: 250)
            HStack(spacing: AppSpacing.md) {
                TextField("Color hex", text: $newColor).textFieldStyle(.roundedBorder).frame(width: 120)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: newColor)).frame(width: 24, height: 24)
            }
            TextField("SF Symbol", text: $newSymbol).textFieldStyle(.roundedBorder).frame(width: 250)
            HStack(spacing: AppSpacing.md) {
                Button(L10n.cancel) { showAddType = false }.buttonStyle(.bordered)
                Button(L10n.confirmEvent) {
                    guard !newName.isEmpty else { return }
                    appState.noiseTypeManager.add(NoiseTypeConfig(name: newName, colorHex: newColor, sfSymbol: newSymbol))
                    newName = ""; showAddType = false
                }
                .buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
        }
        .padding(AppSpacing.xl).frame(width: 400, height: 280)
    }
}
