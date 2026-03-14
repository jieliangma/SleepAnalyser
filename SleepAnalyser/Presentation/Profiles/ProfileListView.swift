import SwiftUI

struct ProfileListView: View {
    @State private var profiles: [UserProfile] = [UserProfile(name: L10n.defaultUser)]
    @State private var showingEditor = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            HStack {
                Text(L10n.profiles).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Button(action: { showingEditor = true }) {
                    Label(L10n.addProfile, systemImage: "plus.circle.fill")
                }
            }
            .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.lg)

            List(profiles) { profile in
                HStack {
                    Image(systemName: "person.circle.fill").font(.system(size: 32)).foregroundStyle(AppColors.primary)
                    VStack(alignment: .leading) {
                        Text(profile.name).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                        Text(profile.preferredInputDeviceUID ?? L10n.defaultMicrophone)
                            .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, AppSpacing.sm)
            }
            .listStyle(.inset)
        }
    }
}
