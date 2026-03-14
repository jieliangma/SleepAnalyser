import SwiftUI

struct ProfileListView: View {
    @State private var profiles: [UserProfile] = [
        UserProfile(name: "Default User")
    ]
    @State private var showingEditor = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            HStack {
                Text("Profiles")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Button(action: { showingEditor = true }) {
                    Label("Add Profile", systemImage: "plus.circle.fill")
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)

            List(profiles) { profile in
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.primary)
                    VStack(alignment: .leading) {
                        Text(profile.name)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(profile.preferredInputDeviceUID ?? "Default Microphone")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, AppSpacing.sm)
            }
            .listStyle(.inset)
        }
    }
}
