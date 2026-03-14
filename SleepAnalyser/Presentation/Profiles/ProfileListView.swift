import SwiftUI

struct ProfileListView: View {
    @Environment(AppState.self) private var appState
    @State private var profiles: [UserProfile] = []
    @State private var showingNewProfile = false
    @State private var newProfileName = ""
    @State private var profileToDelete: UserProfile?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                HStack {
                    Text(L10n.profiles).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Button(action: { showingNewProfile = true }) {
                        Label(L10n.addProfile, systemImage: "plus.circle.fill")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(profiles) { profile in
                    profileCard(profile)
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .task { await loadProfiles() }
        .sheet(isPresented: $showingNewProfile) {
            newProfileSheet
        }
        .alert(
            L10n.profileDeleteTitle,
            isPresented: .init(get: { profileToDelete != nil }, set: { if !$0 { profileToDelete = nil } })
        ) {
            Button(L10n.cancel, role: .cancel) { profileToDelete = nil }
            Button(L10n.profileDeleteConfirm, role: .destructive) {
                guard let profile = profileToDelete else { return }
                Task {
                    try? await appState.profileRepo.deleteProfile(id: profile.id)
                    profileToDelete = nil
                    await loadProfiles()
                }
            }
        } message: {
            if let profile = profileToDelete {
                Text(L10n.profileDeleteMessage(profile.name))
            }
        }
    }

    private func profileCard(_ profile: UserProfile) -> some View {
        let isActive = profile.id == appState.activeProfile?.id
        return HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(isActive ? AppColors.primary.opacity(0.15) : AppColors.surfaceLight)
                    .frame(width: 44, height: 44)
                Image(systemName: isActive ? "checkmark.circle.fill" : "person.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isActive ? AppColors.success : AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppSpacing.sm) {
                    Text(profile.name)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    if isActive {
                        Text(L10n.profileActive)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.success)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppColors.success.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(profile.preferredInputDeviceUID ?? L10n.defaultMicrophone)
                    .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }

            Spacer()

            if !isActive {
                Button {
                    appState.activeProfile = profile
                } label: {
                    Text(L10n.profileSwitch)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    profileToDelete = profile
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.error.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private var newProfileSheet: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(AppColors.primary)

            Text(L10n.addProfile)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            TextField(L10n.defaultUser, text: $newProfileName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            HStack(spacing: AppSpacing.md) {
                Button(L10n.cancel) { showingNewProfile = false }
                    .buttonStyle(.bordered)
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
                .buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
        }
        .padding(AppSpacing.xl)
        .frame(width: 380, height: 240)
    }

    private func loadProfiles() async {
        profiles = (try? await appState.profileRepo.getAllProfiles()) ?? []
        if profiles.isEmpty {
            let name = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()
            let def = UserProfile(name: name)
            try? await appState.profileRepo.createProfile(def)
            profiles = [def]
        }
    }
}
