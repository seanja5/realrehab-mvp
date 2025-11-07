import Combine
import Foundation
import Supabase

@MainActor
final class LessonSessionViewModel: ObservableObject {
  @Published var currentSessionId: UUID?
  @Published var isRecording: Bool = false
  @Published var errorMessage: String?

  func start(programId: UUID?, exerciseId: UUID?) async {
    guard !self.isRecording else { return }
    self.errorMessage = nil

    do {
      let sessionId = try await TelemetryService.startSession(programId: programId, exerciseId: exerciseId)
      self.currentSessionId = sessionId
      self.isRecording = true
      print("LessonSessionViewModel: started session \(sessionId)")
    } catch {
      self.errorMessage = error.localizedDescription
      print("LessonSessionViewModel start error: \(error)")
    }
  }

  func record(
    angle: Double? = nil,
    flexRaw: Int? = nil,
    rateHz: Double? = nil,
    imuQuat: [String: Any]? = nil
  ) async {
    guard let sessionId = self.currentSessionId else { return }

    do {
      try await TelemetryService.recordSample(
        sessionId: sessionId,
        angle: angle,
        flexRaw: flexRaw,
        rateHz: rateHz,
        imuQuat: imuQuat
      )
    } catch {
      self.errorMessage = error.localizedDescription
      print("LessonSessionViewModel record error: \(error)")
    }
  }

  func end() async {
    guard let sessionId = self.currentSessionId else { return }
    do {
      try await TelemetryService.endSession(sessionId: sessionId)
      print("LessonSessionViewModel: ended session \(sessionId)")
      self.currentSessionId = nil
      self.isRecording = false
    } catch {
      self.errorMessage = error.localizedDescription
      print("LessonSessionViewModel end error: \(error)")
    }
  }
}

