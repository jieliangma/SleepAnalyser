import SwiftUI

struct RoomManagementView: View {
    @Environment(AppState.self) private var appState
    @State private var rooms: [RoomProfile] = []
    @State private var showAddRoom = false
    @State private var newRoomName = ""
    @State private var renamingRoom: RoomProfile?
    @State private var renameText = ""
    @State private var roomToDelete: RoomProfile?
    @State private var calibratingRoom: RoomProfile?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                HStack {
                    Text(L10n.rooms).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Button { showAddRoom = true } label: {
                        Label(L10n.addRoom, systemImage: "plus.circle.fill")
                            .font(AppTypography.body).foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }

                if rooms.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "house.fill").font(.system(size: 48)).foregroundStyle(AppColors.textTertiary)
                        Text(L10n.noRooms).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(rooms) { room in roomCard(room) }
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .task { await loadRooms() }
        .sheet(isPresented: $showAddRoom) { addRoomSheet }
        .sheet(item: $renamingRoom) { room in renameSheet(room) }
        .sheet(item: $calibratingRoom) { _ in
            CalibrationView(room: $calibratingRoom, onComplete: { updated in
                Task {
                    if let updated { try? await appState.roomRepo.updateRoom(updated) }
                    await loadRooms()
                    await appState.loadActiveRoom()
                    calibratingRoom = nil
                }
            })
        }
        .alert(L10n.profileDeleteTitle, isPresented: .init(
            get: { roomToDelete != nil }, set: { if !$0 { roomToDelete = nil } }
        )) {
            Button(L10n.cancel, role: .cancel) { roomToDelete = nil }
            Button(L10n.profileDeleteConfirm, role: .destructive) {
                guard let room = roomToDelete else { return }
                Task {
                    try? await appState.roomRepo.deleteRoom(id: room.id)
                    roomToDelete = nil
                    await loadRooms()
                }
            }
        } message: {
            if let room = roomToDelete {
                Text(L10n.profileDeleteMessage(room.name))
            }
        }
    }

    private func roomCard(_ room: RoomProfile) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(room.isSelected ? AppColors.primary.opacity(0.15) : AppColors.surfaceLight)
                    .frame(width: 44, height: 44)
                Image(systemName: room.isSelected ? "checkmark.circle.fill" : "house.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(room.isSelected ? AppColors.success : AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppSpacing.sm) {
                    Text(room.name).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                    if room.isSelected {
                        Text(L10n.profileActive)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.success)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppColors.success.opacity(0.12)).clipShape(Capsule())
                    }
                }
                HStack(spacing: AppSpacing.sm) {
                    if room.isCalibrated {
                        Text(String(format: "%.0f dB", room.baselineNoiseLevel))
                            .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                        if let date = room.lastCalibratedAt {
                            Text(date, style: .date).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                        }
                    } else {
                        Text(L10n.calibrationNone).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    }
                }
            }

            Spacer()

            if !room.isSelected {
                Button {
                    Task {
                        guard let profileId = appState.activeProfile?.id else { return }
                        try? await appState.roomRepo.selectRoom(id: room.id, userProfileId: profileId)
                        await loadRooms()
                        await appState.loadActiveRoom()
                    }
                } label: {
                    Text(L10n.profileSwitch).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.primary).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(AppColors.primary.opacity(0.1)).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                calibratingRoom = room
            } label: {
                Image(systemName: "waveform.badge.mic").font(.system(size: 15)).foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)

            Button {
                renamingRoom = room
                renameText = room.name
            } label: {
                Image(systemName: "pencil").font(.system(size: 13)).foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)

            Button { roomToDelete = room } label: {
                Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(AppColors.error.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.cardPadding).background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private var addRoomSheet: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "house.badge.plus").font(.system(size: 36)).foregroundStyle(AppColors.primary)
            Text(L10n.addRoom).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            TextField(L10n.roomNamePlaceholder, text: $newRoomName).textFieldStyle(.roundedBorder).frame(width: 260)
            HStack(spacing: AppSpacing.md) {
                Button(L10n.cancel) { showAddRoom = false }.buttonStyle(.bordered)
                Button(L10n.addRoom) {
                    guard !newRoomName.isEmpty, let profileId = appState.activeProfile?.id else { return }
                    Task {
                        let room = RoomProfile(userProfileId: profileId, name: newRoomName, isSelected: rooms.isEmpty)
                        try? await appState.roomRepo.createRoom(room)
                        newRoomName = ""
                        showAddRoom = false
                        await loadRooms()
                        if rooms.count == 1 { await appState.loadActiveRoom() }
                    }
                }
                .buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
        }
        .padding(AppSpacing.xl).frame(width: 380, height: 220)
    }

    private func renameSheet(_ room: RoomProfile) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Text(L10n.renameRoom).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            TextField(room.name, text: $renameText).textFieldStyle(.roundedBorder).frame(width: 260)
            HStack(spacing: AppSpacing.md) {
                Button(L10n.cancel) { renamingRoom = nil }.buttonStyle(.bordered)
                Button(L10n.confirmEvent) {
                    guard !renameText.isEmpty else { return }
                    Task {
                        var updated = room
                        updated.name = renameText
                        try? await appState.roomRepo.updateRoom(updated)
                        renamingRoom = nil
                        await loadRooms()
                    }
                }
                .buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
        }
        .padding(AppSpacing.xl).frame(width: 380, height: 180)
    }

    private func loadRooms() async {
        guard let profileId = appState.activeProfile?.id else { return }
        rooms = (try? await appState.roomRepo.getRooms(for: profileId)) ?? []
    }
}
