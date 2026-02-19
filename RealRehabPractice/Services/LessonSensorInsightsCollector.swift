//
//  LessonSensorInsightsCollector.swift
//  RealRehabPractice
//
//  Collects sensor insights during a lesson: events (errors), IMU samples, shake frequency.
//  Draft saved to RealRehabSensorInsights/{lessonId}.json; enqueued for Supabase sync.
//

import Foundation

// MARK: - Event types (red screen errors)

enum LessonSensorEventType: String, Codable {
    case maxNotReached = "max_not_reached"
    case tooFast = "too_fast"
    case tooSlow = "too_slow"
    case driftLeft = "drift_left"
    case driftRight = "drift_right"
    case shake = "shake"
}

// MARK: - Event model (stored event)

struct LessonSensorEventRecord: Codable {
    let eventType: String
    let repAttempt: Int
    let timeSec: Double
}

// MARK: - Sample models

struct IMUSample: Codable {
    let timeMs: Int
    let imuValue: Double
}

struct ShakeSample: Codable {
    let timeMs: Int
    let frequency: Double
}

// MARK: - Draft payload (matches Supabase table shape)

struct LessonSensorInsightsDraft: Codable {
    var lessonId: UUID
    var patientProfileId: UUID
    var ptProfileId: UUID
    var startedAt: Date
    var completedAt: Date?
    var totalDurationSec: Int
    var repsTarget: Int
    var repsCompleted: Int
    var repsAttempted: Int
    var events: [LessonSensorEventRecord]
    var imuSamples: [IMUSample]
    var shakeFrequencySamples: [ShakeSample]
}

// MARK: - Shake frequency calculator

/// Computes oscillation frequency from a sliding window of raw IMU values.
/// Rapid sign changes or high-frequency variance indicate shake.
enum ShakeFrequencyCalculator {
    private static let windowSize = 20
    private static let sampleIntervalMs = 100

    /// Returns a frequency metric 0...1. Higher = more shake.
    /// Uses zero-crossing rate and variance of first derivative.
    static func computeFrequency(from recentValues: [Double]) -> Double {
        guard recentValues.count >= 3 else { return 0 }
        let values = Array(recentValues.suffix(windowSize))
        let n = values.count

        // Zero-crossing rate (normalized)
        var crossings = 0
        for i in 1..<n {
            if (values[i] > 0 && values[i - 1] <= 0) || (values[i] < 0 && values[i - 1] >= 0) {
                crossings += 1
            }
        }
        let zcr = Double(crossings) / Double(n - 1)

        // Variance of first derivative (rapid changes = shake)
        var derivatives: [Double] = []
        for i in 1..<n {
            derivatives.append(abs(values[i] - values[i - 1]))
        }
        let mean = derivatives.reduce(0, +) / Double(derivatives.count)
        let variance = derivatives.map { pow($0 - mean, 2) }.reduce(0, +) / Double(derivatives.count)
        let normalizedVariance = min(variance / 4.0, 1.0) // scale

        // Combine: high ZCR or high variance = shake
        let score = min(1.0, zcr * 2.0 + normalizedVariance)
        return max(0, min(1.0, score))
    }
}

// MARK: - Collector

@MainActor
final class LessonSensorInsightsCollector {
    static let shared = LessonSensorInsightsCollector()

    private let fileManager = FileManager.default
    private var draftDirectory: URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("RealRehabSensorInsights", isDirectory: true)
    }

    private var draft: LessonSensorInsightsDraft?
    private var imuHistory: [Double] = []
    private let maxIMUHistory = 50
    private var sampleTimer: Timer?
    private var lessonStartTime: Date?

    private init() {
        try? fileManager.createDirectory(at: draftDirectory, withIntermediateDirectories: true)
    }

    /// Start collection for a lesson. Call when lesson begins.
    func start(
        lessonId: UUID,
        patientProfileId: UUID,
        ptProfileId: UUID,
        repsTarget: Int
    ) {
        stop()
        let now = Date()
        draft = LessonSensorInsightsDraft(
            lessonId: lessonId,
            patientProfileId: patientProfileId,
            ptProfileId: ptProfileId,
            startedAt: now,
            completedAt: nil,
            totalDurationSec: 0,
            repsTarget: repsTarget,
            repsCompleted: 0,
            repsAttempted: repsTarget,
            events: [],
            imuSamples: [],
            shakeFrequencySamples: []
        )
        imuHistory = []
        lessonStartTime = now
        start100msSampling()
    }

    /// Record an error event (red screen).
    func recordEvent(
        type: LessonSensorEventType,
        repAttempt: Int,
        timeSec: Double
    ) {
        guard var d = draft else { return }
        let ev = LessonSensorEventRecord(eventType: type.rawValue, repAttempt: repAttempt, timeSec: timeSec)
        d.events.append(ev)
        d.repsAttempted = d.repsTarget + d.events.count
        draft = d
    }

    /// Sample IMU value (call every 100ms). Appends to imu_samples and updates shake buffer.
    func sampleIMU(imuValue: Float, timeMs: Int) {
        guard var d = draft else { return }
        let val = Double(imuValue)
        d.imuSamples.append(IMUSample(timeMs: timeMs, imuValue: val))
        imuHistory.append(val)
        if imuHistory.count > maxIMUHistory {
            imuHistory.removeFirst()
        }
        let frequency = ShakeFrequencyCalculator.computeFrequency(from: imuHistory)
        d.shakeFrequencySamples.append(ShakeSample(timeMs: timeMs, frequency: frequency))
        draft = d
    }

    /// Update reps and duration. Call on rep completion or lesson end.
    func updateProgress(repsCompleted: Int, totalDurationSec: Int) {
        guard var d = draft else { return }
        d.repsCompleted = repsCompleted
        d.totalDurationSec = totalDurationSec
        d.repsAttempted = d.repsTarget + d.events.count
        draft = d
    }

    /// Finish lesson and write draft to disk. Call when lesson completes.
    func finishAndSaveDraft(completed: Bool) {
        stop100msSampling()
        guard var d = draft else { return }
        d.completedAt = Date()
        d.repsAttempted = d.repsTarget + d.events.count
        draft = d
        writeDraftToDisk()
        if completed {
            enqueueForSync()
        }
        draft = nil
        lessonStartTime = nil
    }

    /// Pause collection and persist draft to disk (no sync, no completedAt). Call when lesson is paused.
    func pauseAndPersistDraft(repsCompleted: Int, totalDurationSec: Int) {
        updateProgress(repsCompleted: repsCompleted, totalDurationSec: totalDurationSec)
        writeDraftToDisk()
        stop100msSampling()
        draft = nil
        lessonStartTime = nil
    }

    /// Resume collection from persisted draft. Call when lesson is resumed after pause. Returns false if no draft on disk.
    func resumeFromDraft(lessonId: UUID) -> Bool {
        stop()
        guard var loaded = loadDraft(lessonId: lessonId) else { return false }
        loaded.completedAt = nil
        draft = loaded
        lessonStartTime = loaded.startedAt
        let samples = loaded.imuSamples.suffix(maxIMUHistory)
        imuHistory = samples.map { $0.imuValue }
        start100msSampling()
        return true
    }

    /// Write draft to RealRehabSensorInsights/{lessonId}.json
    private func writeDraftToDisk() {
        guard let d = draft else { return }
        let fileURL = draftDirectory.appendingPathComponent("\(d.lessonId.uuidString).json")
        let tempURL = draftDirectory.appendingPathComponent("\(d.lessonId.uuidString).tmp.json")
        if let data = try? JSONEncoder().encode(d) {
            try? data.write(to: tempURL)
            var resultURL: NSURL?
            try? fileManager.replaceItem(at: fileURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: &resultURL)
        }
    }

    /// Save intermediate draft (e.g. on rep end or pause) without finishing.
    func saveDraftIntermediate(repsCompleted: Int, totalDurationSec: Int) {
        updateProgress(repsCompleted: repsCompleted, totalDurationSec: totalDurationSec)
        writeDraftToDisk()
    }

    private func start100msSampling() {
        stop100msSampling()
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick100ms()
            }
        }
        RunLoop.main.add(sampleTimer!, forMode: .common)
    }

    private func stop100msSampling() {
        sampleTimer?.invalidate()
        sampleTimer = nil
    }

    private func tick100ms() {
        guard let start = lessonStartTime else { return }
        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
        let imu = BluetoothManager.shared.currentIMUValue ?? 0
        sampleIMU(imuValue: imu, timeMs: elapsedMs)
    }

    private func enqueueForSync() {
        guard let d = draft else { return }
        OutboxSyncManager.shared.enqueueLessonSensorInsights(draft: d)
    }

    /// Stop collection without finishing (e.g. lesson aborted).
    func stop() {
        stop100msSampling()
        draft = nil
        lessonStartTime = nil
        imuHistory = []
    }

    /// Load draft from disk (e.g. for offline display or retry sync).
    func loadDraft(lessonId: UUID) -> LessonSensorInsightsDraft? {
        let fileURL = draftDirectory.appendingPathComponent("\(lessonId.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(LessonSensorInsightsDraft.self, from: data) else {
            return nil
        }
        return decoded
    }
}
