import SwiftUI

struct ProfileListView: View {
    @Environment(AppState.self) private var appState
    @State private var profiles: [UserProfile] = []
    @State private var showingNewProfile = false
    @State private var newProfileName = ""

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            HStack {
                Text(L10n.profiles).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Button(action: { showingNewProfile = true }) {
                    Label(L10n.addProfile, systemImage: "plus.circle.fill")
                }
            }
            .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.lg)

            List(profiles) { profile in
                HStack {
                    Image(systemName: profile.id == appState.activeProfile?.id ? "checkmark.circle.fill" : "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(profile.id == appState.activeProfile?.id ? AppColors.success : AppColors.primary)
                    VStack(alignment: .leading) {
                        Text(profile.name).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                        Text(profile.preferredInputDeviceUID ?? L10n.defaultMicrophone)
                            .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    if profile.id != appState.activeProfile?.id {
                        Button(L10n.dashboard) {
                            Task {
                                try? await appState.profileRepo.updateProfile(profile)
                                appState.activeProfile = profile
                            }
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .padding(.vertical, AppSpacing.sm)
                .contentShape(Rectangle())
            }
            .listStyle(.inset)
        }
        .task { await loadProfiles() }
        .sheet(isPresented: $showingNewProfile) {
            VStack(spacing: AppSpacing.md) {
                Text(L10n.addProfile).font(AppTypography.headline)
                TextField(L10n.defaultUser, text: $newProfileName)
                    .textFieldStyle(.roundedBorder).frame(width: 250)
                HStack {
                    Button(L10n.stop) { showingNewProfile = false }.buttonStyle(.bordered)
                    Button(L10n.addProfile) {
                        guard !newProfileName.isEmpty else { return }
                        Task {
                            let profile = UserProfile(name: newProfileName)
                            try? await appState.profileRepo.createProfile(profile)
                            newProfileName = ""
                            showingNewProfile = false
                            await loadProfiles()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(AppSpacing.xl).frame(width: 350)
        }
    }

    private func loadProfiles() async {
        profiles = (try? await appState.profileRepo.getAllProfiles()) ?? []
        if profiles.isEmpty {
            let def = UserProfile(name: L10n.defaultUser)
            try? await appState.profileRepo.createProfile(def)
            profiles = [def]
        }
    }
}
