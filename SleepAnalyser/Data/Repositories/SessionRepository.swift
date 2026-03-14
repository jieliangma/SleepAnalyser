import Foundation
import SwiftData

final class SessionRepository: @unchecked Sendable {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func createSession(_ session: SleepSession) async throws {
        let context = persistence.newBackgroundContext()
        let sd = SleepSessionMapper.toSD(session)
        context.insert(sd)
        try context.save()
    }

    func getSession(id: UUID) async throws -> SleepSession? {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDSleepSession> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let sd = try context.fetch(descriptor).first else { return nil }
        return SleepSessionMapper.toDomain(sd)
    }

    func updateSession(_ session: SleepSession) async throws {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDSleepSession> { $0.id == session.id }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let sd = try context.fetch(descriptor).first else { return }
        SleepSessionMapper.update(sd, from: session)
        try context.save()
    }

    func deleteSession(id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDSleepSession> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let sd = try context.fetch(descriptor).first {
            context.delete(sd)
            try context.save()
        }
    }

    func getSessions(from: Date, to: Date) async throws -> [SleepSession] {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDSleepSession> { $0.startAt >= from && $0.startAt <= to }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startAt, order: .reverse)])
        return try context.fetch(descriptor).map { SleepSessionMapper.toDomain($0) }
    }

    func getLatestSession(profileId: UUID) async throws -> SleepSession? {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDSleepSession> { $0.profileId == profileId }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { SleepSessionMapper.toDomain($0) }
    }

    func addEpoch(_ epoch: SleepEpoch, toSession sessionId: UUID) async throws {
        let context = persistence.newBackgroundContext()
        let sd = EpochMapper.toSD(epoch)
        context.insert(sd)
        try context.save()
    }

    func getEpochs(forSession sessionId: UUID) async throws -> [SleepEpoch] {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDSleepEpoch> { $0.sessionId == sessionId }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.timestamp)])
        return try context.fetch(descriptor).map { EpochMapper.toDomain($0) }
    }

    func addEvent(_ event: AudioEvent, toSession sessionId: UUID) async throws {
        let context = persistence.newBackgroundContext()
        let sd = EventMapper.toSD(event)
        context.insert(sd)
        try context.save()
    }

    func getEvents(forSession sessionId: UUID) async throws -> [AudioEvent] {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDAudioEvent> { $0.sessionId == sessionId }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startAt)])
        return try context.fetch(descriptor).map { EventMapper.toDomain($0) }
    }
}
