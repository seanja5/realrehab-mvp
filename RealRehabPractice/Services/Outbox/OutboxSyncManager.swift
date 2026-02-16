//
//  OutboxSyncManager.swift
//  RealRehabPractice
//
//  Local-first write queue. Persists to disk, processes when online with exponential backoff.
//

import Foundation
import Supabase
import Combine

@MainActor
final class OutboxSyncManager: ObservableObject {
    static let shared = OutboxSyncManager()

    private let maxRetries = 5
    private let fileManager = FileManager.default
    private var outboxDirectory: URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("RealRehabOutbox", isDirectory: true)
    }
    private var outboxFile: URL {
        outboxDirectory.appendingPathComponent("outbox.json")
    }

    private init() {
        try? fileManager.createDirectory(at: outboxDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Enqueue

    func enqueue(_ item: OutboxItem) {
        var items = loadItems()
        items.append(item)
        saveItems(items)
    }

    func enqueueLessonProgress(patientProfileId: UUID, lessonId: UUID, repsCompleted: Int, repsTarget: Int, elapsedSeconds: Int, status: String) {
        let payload = LessonProgressPayload(
            patientProfileId: patientProfileId,
            lessonId: lessonId,
            repsCompleted: repsCompleted,
            repsTarget: repsTarget,
            elapsedSeconds: elapsedSeconds,
            status: status
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let item = OutboxItem(
            id: UUID(),
            createdAt: Date(),
            type: .lessonProgress,
            payload: data,
            retryCount: 0,
            lastAttemptAt: nil
        )
        enqueue(item)
    }

    /// Enqueue a clear (delete) of one lesson's progress so PT and patient see it cleared after restart.
    func enqueueLessonProgressClear(patientProfileId: UUID, lessonId: UUID) {
        let payload = LessonProgressClearPayload(patientProfileId: patientProfileId, lessonId: lessonId)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let item = OutboxItem(
            id: UUID(),
            createdAt: Date(),
            type: .lessonProgressClear,
            payload: data,
            retryCount: 0,
            lastAttemptAt: nil
        )
        enqueue(item)
    }

    func enqueueLessonSensorInsights(draft: LessonSensorInsightsDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        let item = OutboxItem(
            id: UUID(),
            createdAt: Date(),
            type: .lessonSensorInsights,
            payload: data,
            retryCount: 0,
            lastAttemptAt: nil
        )
        enqueue(item)
    }

    // MARK: - Process

    func processQueueIfOnline() async {
        guard NetworkMonitor.shared.isOnline else { return }
        var items = loadItems()
        guard !items.isEmpty else { return }

        var modified = false
        for index in items.indices.reversed() {
            let item = items[index]
            if let backoff = backoffSeconds(for: item), backoff > 0 {
                continue
            }
            do {
                try await processItem(item)
                items.remove(at: index)
                modified = true
            } catch {
                var updated = item
                updated.retryCount += 1
                updated.lastAttemptAt = Date()
                if updated.retryCount < maxRetries {
                    items[index] = updated
                    modified = true
                } else {
                    items.remove(at: index)
                    modified = true
                }
            }
        }
        if modified {
            saveItems(items)
        }
    }

    private func backoffSeconds(for item: OutboxItem) -> Double? {
        guard item.retryCount > 0, let last = item.lastAttemptAt else { return nil }
        let delay = pow(2.0, Double(item.retryCount))
        let nextAttempt = last.addingTimeInterval(delay)
        return max(0, nextAttempt.timeIntervalSinceNow)
    }

    private func processItem(_ item: OutboxItem) async throws {
        switch item.type {
        case .lessonProgress:
            try await syncLessonProgress(payload: item.payload)
        case .lessonProgressClear:
            try await syncLessonProgressClear(payload: item.payload)
        case .lessonSensorInsights:
            try await syncLessonSensorInsights(payload: item.payload)
        }
    }

    private func syncLessonSensorInsights(payload: Data) async throws {
        let draft = try JSONDecoder().decode(LessonSensorInsightsDraft.self, from: payload)
        try await LessonSensorInsightsSync.upsert(draft: draft)
    }

    private func syncLessonProgress(payload: Data) async throws {
        let p = try JSONDecoder().decode(LessonProgressPayload.self, from: payload)
        let patientProfileId = p.patientProfileId

        // RPC call in LessonProgressSync (nonisolated) to avoid Sendable/Encodable isolation error
        try await LessonProgressSync.upsert(
            lessonId: p.lessonId.uuidString,
            repsCompleted: p.repsCompleted,
            repsTarget: p.repsTarget,
            elapsedSeconds: p.elapsedSeconds,
            status: p.status
        )

        // Invalidate cache so next load reflects the update
        await CacheService.shared.invalidate(CacheKey.lessonProgress(patientProfileId: patientProfileId))
    }

    private func syncLessonProgressClear(payload: Data) async throws {
        let p = try JSONDecoder().decode(LessonProgressClearPayload.self, from: payload)
        try await LessonProgressSync.delete(lessonId: p.lessonId.uuidString)
        await CacheService.shared.invalidate(CacheKey.lessonProgress(patientProfileId: p.patientProfileId))
    }

    // MARK: - Persistence

    private func loadItems() -> [OutboxItem] {
        guard fileManager.fileExists(atPath: outboxFile.path),
              let data = try? Data(contentsOf: outboxFile),
              let decoded = try? JSONDecoder().decode([OutboxItem].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveItems(_ items: [OutboxItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        let tempURL = outboxDirectory.appendingPathComponent("outbox.tmp.json")
        try? data.write(to: tempURL)
        var resultURL: NSURL?
        try? fileManager.replaceItem(at: outboxFile, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: &resultURL)
    }
}

