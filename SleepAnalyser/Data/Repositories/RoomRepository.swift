import Foundation
import SwiftData

final class RoomRepository: @unchecked Sendable {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func createRoom(_ room: RoomProfile) async throws {
        let context = persistence.newBackgroundContext()
        context.insert(SDRoomProfile(
            id: room.id, userProfileId: room.userProfileId, name: room.name,
            baselineNoiseLevel: room.baselineNoiseLevel, micGainFactor: room.micGainFactor,
            noiseFloorSpectrum: room.noiseFloorSpectrum, lastCalibratedAt: room.lastCalibratedAt,
            isSelected: room.isSelected
        ))
        try context.save()
    }

    func getRooms(for userProfileId: UUID) async throws -> [RoomProfile] {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDRoomProfile> { $0.userProfileId == userProfileId }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor).map { mapToDomain($0) }
    }

    func getSelectedRoom(for userProfileId: UUID) async throws -> RoomProfile? {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDRoomProfile> { $0.userProfileId == userProfileId && $0.isSelected == true }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { mapToDomain($0) }
    }

    func selectRoom(id: UUID, userProfileId: UUID) async throws {
        let context = persistence.newBackgroundContext()
        let allPredicate = #Predicate<SDRoomProfile> { $0.userProfileId == userProfileId }
        let all = try context.fetch(FetchDescriptor(predicate: allPredicate))
        for room in all { room.isSelected = (room.id == id) }
        try context.save()
    }

    func updateRoom(_ room: RoomProfile) async throws {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDRoomProfile> { $0.id == room.id }
        guard let sd = try context.fetch(FetchDescriptor(predicate: predicate)).first else { return }
        sd.name = room.name
        sd.baselineNoiseLevel = room.baselineNoiseLevel
        sd.micGainFactor = room.micGainFactor
        sd.noiseFloorSpectrum = room.noiseFloorSpectrum
        sd.lastCalibratedAt = room.lastCalibratedAt
        sd.isSelected = room.isSelected
        try context.save()
    }

    func deleteRoom(id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDRoomProfile> { $0.id == id }
        if let sd = try context.fetch(FetchDescriptor(predicate: predicate)).first {
            context.delete(sd)
            try context.save()
        }
    }

    private func mapToDomain(_ sd: SDRoomProfile) -> RoomProfile {
        RoomProfile(
            id: sd.id, userProfileId: sd.userProfileId, name: sd.name,
            baselineNoiseLevel: sd.baselineNoiseLevel, micGainFactor: sd.micGainFactor,
            noiseFloorSpectrum: sd.noiseFloorSpectrum, lastCalibratedAt: sd.lastCalibratedAt,
            isSelected: sd.isSelected
        )
    }
}
