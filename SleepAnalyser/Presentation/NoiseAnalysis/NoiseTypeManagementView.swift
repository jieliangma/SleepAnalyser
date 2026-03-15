import SwiftUI
import AVFoundation

struct NoiseTypeManagementView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddType = false
    @State private var newName = ""
    @State private var newColor = "64748B"
    @State private var newSymbol = "waveform"
    @State private var editingConfig: NoiseTypeConfig?
    @State private var editName = ""
    @State private var clipAmps: [URL: [Float]] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                HStack {
                    Text(L10n.noiseTypes).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Button { showAddType = true } label: {
                        Label(L10n.addNoiseType, systemImage: "plus.circle.fill")
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
        .sheet(item: $editingConfig) { config in
            editTypeSheet(config)
        }
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
                Button {
                    editName = config.name
                    editingConfig = config
                } label: {
                    Image(systemName: "pencil").font(.system(size: 12)).foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
                if !NoiseTypeConfig.builtIn.contains(where: { $0.name == config.name }) {
                    Button { appState.noiseTypeManager.delete(id: config.id) } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(AppColors.error.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(Array(config.soundClipURLs.enumerated()), id: \.offset) { idx, url in
                clipRow(config: config, idx: idx, url: url)
            }
        }
        .padding(AppSpacing.cardPadding).background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private func clipRow(config: NoiseTypeConfig, idx: Int, url: URL) -> some View {
        let clipId = UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", abs(url.hashValue) & 0xFFFFFFFFFFFF))") ?? UUID()
        let amps = clipAmps[url] ?? []
        return VStack(spacing: 2) {
            HStack(spacing: AppSpacing.sm) {
                Button {
                    appState.audioPlayer.toggle(url: url, eventId: clipId)
                } label: {
                    Image(systemName: appState.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11)).foregroundStyle(Color(hex: config.colorHex))
                }
                .buttonStyle(.plain).frame(width: 20)

                GeometryReader { geo in
                    Canvas { context, size in
                        let w = size.width, h = size.height, midY = h / 2
                        guard !amps.isEmpty else { return }
                        let maxA = amps.max() ?? 1
                        let s: Float = maxA > 0 ? 1.0 / maxA : 1
                        for (i, amp) in amps.enumerated() {
                            let x = Double(i) / Double(amps.count) * w
                            let barH = Double(amp * s) * h * 0.85
                            var p = Path()
                            p.addRect(CGRect(x: x, y: midY - barH / 2, width: 1, height: max(barH, 0.5)))
                            context.fill(p, with: .color(Color(hex: config.colorHex).opacity(0.6)))
                        }

                        if appState.audioPlayer.isPlaying && appState.audioPlayer.duration > 0 {
                            let progress = appState.audioPlayer.currentTime / appState.audioPlayer.duration
                            var cursor = Path()
                            cursor.move(to: CGPoint(x: progress * w, y: 0))
                            cursor.addLine(to: CGPoint(x: progress * w, y: h))
                            context.stroke(cursor, with: .color(.white), lineWidth: 1)
                        }
                    }
                    .frame(height: 28)
                }
                .frame(height: 28)

                Text(url.lastPathComponent.prefix(15))
                    .font(.system(size: 9)).foregroundStyle(AppColors.textTertiary).lineLimit(1).frame(width: 70)

                Button {
                    appState.audioPlayer.stop()
                    appState.noiseTypeManager.removeSoundClip(from: config.name, at: idx)
                    clipAmps.removeValue(forKey: url)
                } label: {
                    Image(systemName: "xmark.circle").font(.system(size: 10)).foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
        .onAppear { loadClipAmplitudes(url: url) }
    }

    private func loadClipAmplitudes(url: URL) {
        guard clipAmps[url] == nil, let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.isMeteringEnabled = true
        let duration = player.duration
        let sampleCount = max(100, Int(duration * 30))
        var amps: [Float] = []
        for i in 0..<sampleCount {
            let t = duration * Double(i) / Double(sampleCount)
            player.currentTime = t
            player.updateMeters()
            let db = player.averagePower(forChannel: 0)
            let linear = pow(10, db / 20)
            amps.append(linear)
        }
        player.stop()
        clipAmps[url] = amps
    }

    private func editTypeSheet(_ config: NoiseTypeConfig) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Text(L10n.renameRoom).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            TextField(config.name, text: $editName).textFieldStyle(.roundedBorder).frame(width: 260)
            HStack(spacing: AppSpacing.md) {
                Button(L10n.cancel) { editingConfig = nil }.buttonStyle(.bordered)
                Button(L10n.confirmEvent) {
                    guard !editName.isEmpty else { return }
                    var updated = config
                    updated.name = editName
                    appState.noiseTypeManager.update(updated)
                    editingConfig = nil
                }
                .buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
        }
        .padding(AppSpacing.xl).frame(width: 380, height: 170)
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

extension NoiseTypeConfig: Hashable {
    static func == (lhs: NoiseTypeConfig, rhs: NoiseTypeConfig) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
