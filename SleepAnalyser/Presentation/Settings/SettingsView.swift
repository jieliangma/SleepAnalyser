import SwiftUI
import AVFoundation
import Accelerate

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            settingsTabs
            Divider().foregroundStyle(AppColors.surfaceLight)
            TabContent(selectedTab: selectedTab)
        }
        .background(AppColors.background)
    }

    private var settingsTabs: some View {
        HStack(spacing: AppSpacing.xs) {
            tabButton(L10n.profiles, icon: "person.2.fill", tag: 0)
            tabButton(L10n.rooms, icon: "house.fill", tag: 1)
            tabButton(L10n.audio, icon: "mic.fill", tag: 2)
            tabButton(L10n.storage, icon: "internaldrive.fill", tag: 3)
            tabButton(L10n.language, icon: "globe", tag: 4)
            tabButton(L10n.privacy, icon: "lock.fill", tag: 5)
            tabButton(L10n.about, icon: "info.circle.fill", tag: 6)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.sm)
    }

    private func tabButton(_ title: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tag }
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: selectedTab == tag ? .semibold : .regular))
                .foregroundStyle(selectedTab == tag ? AppColors.primary : AppColors.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selectedTab == tag ? AppColors.primary.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct TabContent: View {
    let selectedTab: Int

    var body: some View {
        switch selectedTab {
        case 0:
            ProfileListView()
        case 1:
            RoomManagementView()
        case 2:
            AudioSettingsSection()
        case 3:
            ScrollView {
                VStack(spacing: AppSpacing.lg) { StorageSection() }.padding(AppSpacing.lg)
            }
        case 4:
            ScrollView {
                VStack(spacing: AppSpacing.lg) { LanguageSection() }.padding(AppSpacing.lg)
            }
        case 5:
            ScrollView {
                VStack(spacing: AppSpacing.lg) { PrivacySection() }.padding(AppSpacing.lg)
            }
        case 6:
            ScrollView {
                VStack(spacing: AppSpacing.lg) { AboutSection() }.padding(AppSpacing.lg)
            }
        default:
            EmptyView()
        }
    }
}

private struct AudioSettingsSection: View {
    @State private var audioSubTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.xs) {
                audioSubTabButton(L10n.noiseAnalysis, tag: 0)
                audioSubTabButton(L10n.audioInputOutput, tag: 1)
                audioSubTabButton(L10n.noiseTypes, tag: 2)
                audioSubTabButton(L10n.audioFilterTest, tag: 3)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            switch audioSubTab {
            case 0: NoiseAnalysisView()
            case 1:
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        AudioSection()
                        AudioOutputSection()
                    }.padding(AppSpacing.lg)
                }
            case 2: NoiseTypeManagementView()
            case 3:
                ScrollView {
                    VStack(spacing: AppSpacing.lg) { AudioFilterTestSection() }.padding(AppSpacing.lg)
                }
            default: EmptyView()
            }
        }
    }

    private func audioSubTabButton(_ title: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { audioSubTab = tag }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: audioSubTab == tag ? .semibold : .regular))
                .foregroundStyle(audioSubTab == tag ? AppColors.primary : AppColors.textTertiary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(audioSubTab == tag ? AppColors.primary.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct StorageSection: View {
    @Environment(AppState.self) private var appState
    @State private var maxSizeGB: Double = Double(StorageSettings.maxSizeBytes) / (1024 * 1024 * 1024)
    @State private var maxDays: Double = Double(StorageSettings.maxRetentionDays)
    @State private var currentUsageBytes: Int64 = 0
    @State private var recordingCount: Int = 0
    @State private var showDeleteConfirm = false

    var body: some View {
        SettingsCard(title: L10n.storageManagement, icon: "internaldrive.fill") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                usageRow

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.maxStorageSize).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(formatGB(maxSizeGB)).font(AppTypography.caption).foregroundStyle(AppColors.textPrimary)
                    }
                    Slider(value: $maxSizeGB, in: 1...30, step: 1)
                        .tint(AppColors.primary)
                        .onChange(of: maxSizeGB) { _, val in
                            StorageSettings.maxSizeBytes = Int64(val * 1024 * 1024 * 1024)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.maxStorageDays).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(L10n.storageDaysValue(Int(maxDays))).font(AppTypography.caption).foregroundStyle(AppColors.textPrimary)
                    }
                    Slider(value: $maxDays, in: 1...365, step: 1)
                        .tint(AppColors.primary)
                        .onChange(of: maxDays) { _, val in
                            StorageSettings.maxRetentionDays = Int(val)
                        }
                }

                Text(L10n.storageNote)
                    .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)

                Divider().foregroundStyle(AppColors.surfaceLight)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(L10n.deleteAllData, systemImage: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.error)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(AppColors.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { refreshUsage() }
        .alert(L10n.deleteAllData, isPresented: $showDeleteConfirm) {
            Button(L10n.deleteAllData, role: .destructive) {
                Task { await appState.deleteAllData() }
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }

    private var usageRow: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.currentUsage).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                Text(formatBytes(currentUsageBytes))
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.recordingCount).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                Text("\(recordingCount)")
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func refreshUsage() {
        let recordings = appState.recordingManager.allRecordings()
        recordingCount = recordings.count
        currentUsageBytes = recordings.reduce(0) { $0 + $1.totalSize }
    }

    private func formatGB(_ gb: Double) -> String {
        gb.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(gb)) GB" : String(format: "%.1f GB", gb)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        return mb >= 1024 ? String(format: "%.1f GB", mb / 1024) : String(format: "%.1f MB", mb)
    }
}

enum StorageSettings {
    private static let maxSizeKey = "storage.maxSizeBytes"
    private static let maxDaysKey = "storage.maxRetentionDays"

    static var maxSizeBytes: Int64 {
        get {
            let val = UserDefaults.standard.integer(forKey: maxSizeKey)
            return val > 0 ? Int64(val) : 10 * 1024 * 1024 * 1024
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: maxSizeKey) }
    }

    static var maxRetentionDays: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: maxDaysKey)
            return val > 0 ? val : 7
        }
        set { UserDefaults.standard.set(newValue, forKey: maxDaysKey) }
    }
}

private struct LanguageSection: View {
    @Bindable private var languageManager = LanguageManager.shared

    var body: some View {
        SettingsCard(title: L10n.languageSelection, icon: "globe") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Picker(L10n.language, selection: $languageManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.nativeDisplayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)

                Text(L10n.languageNote)
                    .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}

private struct AudioSection: View {
    @Environment(AppState.self) private var appState
    @State private var selectedDeviceUID: String = ""
    @State private var sensitivity: Double = 1.0

    var body: some View {
        SettingsCard(title: L10n.audioInput, icon: "mic.fill") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Picker(L10n.microphone, selection: $selectedDeviceUID) {
                    ForEach(appState.deviceManager.availableDevices, id: \.id) { device in
                        Text(device.name).tag(device.id)
                    }
                    if appState.deviceManager.availableDevices.isEmpty {
                        Text(L10n.defaultMicrophone).tag("")
                    }
                }
                .onChange(of: selectedDeviceUID) { _, newUID in
                    guard !newUID.isEmpty, let profile = appState.activeProfile else { return }
                    Task {
                        try? await appState.captureService.switchDevice(uid: newUID)
                        var updated = profile
                        updated.preferredInputDeviceUID = newUID
                        try? await appState.profileRepo.updateProfile(updated)
                        appState.activeProfile = updated
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.sensitivity).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    Slider(value: $sensitivity, in: 0.5...2.0)
                        .tint(AppColors.primary)
                }

                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(appState.micPermissionGranted ? AppColors.success : AppColors.error)
                        .frame(width: 8, height: 8)
                    Text(appState.micPermissionGranted ? L10n.signalGood : "No Permission")
                        .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if !appState.micPermissionGranted {
                        Button("Grant Access") {
                            Task { await appState.requestMicPermission() }
                        }
                        .font(AppTypography.caption)
                        .buttonStyle(.borderedProminent).tint(AppColors.primary).controlSize(.small)
                    }
                }
            }
        }
        .onAppear {
            selectedDeviceUID = appState.activeProfile?.preferredInputDeviceUID ?? appState.deviceManager.availableDevices.first?.id ?? ""
        }
    }

    private func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value).font(AppTypography.body).foregroundStyle(AppColors.textPrimary)
        }
    }
}

private struct AudioOutputSection: View {
    @Environment(AppState.self) private var appState
    @State private var selectedDeviceUID: String = ""

    var body: some View {
        SettingsCard(title: L10n.audioOutput, icon: "speaker.wave.2.fill") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Picker(L10n.speaker, selection: $selectedDeviceUID) {
                    Text(L10n.defaultSpeaker).tag("")
                    ForEach(appState.deviceManager.availableOutputDevices, id: \.id) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .onChange(of: selectedDeviceUID) { _, newUID in
                    if newUID.isEmpty { return }
                    appState.deviceManager.setDefaultOutputDevice(uid: newUID)
                }
            }
        }
        .onAppear {
            selectedDeviceUID = appState.deviceManager.defaultOutputDeviceUID
        }
    }
}

private struct PrivacySection: View {
    var body: some View {
        SettingsCard(title: L10n.data, icon: "lock.shield.fill") {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(AppColors.success)
                Text(L10n.privacyNote)
                    .font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}

private struct AboutSection: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer().frame(height: AppSpacing.xl)
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.primary)
            Text(L10n.appName).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
            Text(L10n.version).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            Text(L10n.appDescription)
                .font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AudioFilterTestSection: View {
    @Environment(AppState.self) private var appState
    @State private var isRunning = false
    @State private var bypass = false
    @State private var inputLevel: Float = 0
    @State private var outputLevel: Float = 0
    @State private var loopback: AudioFilterLoopback?

    var body: some View {
        SettingsCard(title: L10n.audioFilterTest, icon: "waveform.badge.magnifyingglass") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(L10n.audioFilterTestDesc)
                    .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)

                HStack(spacing: AppSpacing.md) {
                    Button {
                        if isRunning { stopTest() } else { startTest() }
                    } label: {
                        Label(isRunning ? L10n.audioFilterStop : L10n.audioFilterStart,
                              systemImage: isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isRunning ? .white : AppColors.primary)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(isRunning ? AppColors.error : AppColors.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Toggle(L10n.audioFilterBypass, isOn: $bypass)
                        .toggleStyle(.switch)
                        .tint(AppColors.warning)
                        .font(AppTypography.caption)
                        .onChange(of: bypass) { _, newValue in
                            loopback?.bypass = newValue
                        }
                }

                if isRunning {
                    VStack(spacing: AppSpacing.sm) {
                        levelMeter(label: L10n.audioFilterOriginal, level: inputLevel, color: AppColors.textSecondary)
                        levelMeter(label: L10n.audioFilterProcessed, level: outputLevel, color: AppColors.primary)
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Circle().fill(AppColors.error).frame(width: 6, height: 6)
                        Text(L10n.recording)
                            .font(AppTypography.caption).foregroundStyle(AppColors.error)
                        Spacer()
                        Text(bypass ? L10n.audioFilterProcessed : L10n.audioFilterBypass)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(bypass ? AppColors.success : AppColors.warning)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background((bypass ? AppColors.success : AppColors.warning).opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func levelMeter(label: String, level: Float, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 10)).foregroundStyle(AppColors.textTertiary)
                Spacer()
                Text(String(format: "%.1f dB", 20 * log10(max(level, 1e-10))))
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(AppColors.textTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(AppColors.surfaceLight)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, (level * 5)))))
                        .animation(.easeOut(duration: 0.08), value: level)
                }
            }
            .frame(height: 4)
        }
    }

    private func startTest() {
        let lb = AudioFilterLoopback(
            room: appState.activeRoom,
            noiseTypes: appState.noiseTypeManager.types
        )
        lb.bypass = bypass
        lb.onLevels = { input, output in
            DispatchQueue.main.async {
                inputLevel = input
                outputLevel = output
            }
        }
        do {
            try lb.start()
            loopback = lb
            isRunning = true
        } catch {
            loopback = nil
        }
    }

    private func stopTest() {
        loopback?.stop()
        loopback = nil
        isRunning = false
        inputLevel = 0
        outputLevel = 0
    }
}

final class AudioFilterLoopback {
    private var engine: AVAudioEngine?
    private let preprocessor = AudioPreprocessor()
    private let suppressor = NoiseSuppressor()
    private let separator = NoiseSeparatorBridge()
    private let targetSampleRate: Double = 16000.0
    var bypass = false
    var onLevels: ((Float, Float) -> Void)?

    init(room: RoomProfile?, noiseTypes: [NoiseTypeConfig]) {
        if let room {
            suppressor.loadRoomCalibration(
                noiseFloorSpectrum: room.noiseFloorSpectrum,
                baselineNoiseLevel: room.baselineNoiseLevel,
                micGainFactor: room.micGainFactor
            )
            if let specData = room.noiseFloorSpectrum {
                let spectrum = specData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
                separator.loadRoomNoiseFloor(spectrum)
            }
        }

        separator.clearTemplates()
        for config in noiseTypes {
            for clipURL in config.soundClipURLs {
                if let spectrum = extractSpectrumFromClip(clipURL) {
                    let cType = NoiseTypeLabel(rawValue: config.name)?.toCType ?? NS_NOISE_UNKNOWN
                    separator.addNoiseTemplate(type: cType, spectrum: spectrum)
                }
            }
        }
    }

    func start() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let outputNode = engine.outputNode
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        let hwFormat = inputNode.inputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else {
            throw AudioCaptureError.deviceNotFound
        }

        let outputFormat = outputNode.inputFormat(forBus: 0)
        engine.connect(playerNode, to: outputNode, format: outputFormat)

        let bufferSize = AVAudioFrameCount(1024)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hwFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let monoSamples = AudioTapBufferBridge.extractMonoSamples(from: buffer)
            let resampled = AudioTapBufferBridge.resample(
                samples: monoSamples,
                fromRate: hwFormat.sampleRate,
                toRate: self.targetSampleRate
            )

            let inputRMS = self.computeRMS(resampled)
            let processed: [Float]
            if self.bypass {
                let frame = AudioFrame(
                    timestamp: Date(), samples: resampled,
                    sampleRate: self.targetSampleRate, channelCount: 1
                )
                let preResult = self.preprocessor.process(frame: frame)
                processed = self.suppressor.suppress(preResult.samples)
            } else {
                processed = resampled
            }
            let outputRMS = self.computeRMS(processed)
            self.onLevels?(inputRMS, outputRMS)

            let upsampledBack = AudioTapBufferBridge.resample(
                samples: processed,
                fromRate: self.targetSampleRate,
                toRate: outputFormat.sampleRate
            )

            let frameCount = AVAudioFrameCount(upsampledBack.count)
            guard frameCount > 0,
                  let playBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount)
            else { return }
            playBuffer.frameLength = frameCount

            if outputFormat.channelCount >= 1, let ch0 = playBuffer.floatChannelData?[0] {
                for i in 0..<Int(frameCount) {
                    ch0[i] = upsampledBack[i]
                }
            }
            if outputFormat.channelCount >= 2, let ch1 = playBuffer.floatChannelData?[1] {
                for i in 0..<Int(frameCount) {
                    ch1[i] = upsampledBack[i]
                }
            }
            playerNode.scheduleBuffer(playBuffer)
        }

        try engine.start()
        playerNode.play()
        self.engine = engine
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }

    private func computeRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }

    private func extractSpectrumFromClip(_ url: URL) -> [Float]? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let frameCount = AVAudioFrameCount(min(file.length, 16384))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount),
              let _ = try? file.read(into: buffer, frameCount: frameCount),
              let channelData = buffer.floatChannelData else { return nil }
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        let bands = separator.computeBandEnergy(samples: samples)
        return [bands.subBass, bands.bass, bands.lowMid, bands.mid, bands.highMid, bands.presence, bands.brilliance]
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label(title, systemImage: icon)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
            content
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}
