import Combine
import Foundation
import Supabase

@MainActor
final class PTProgramEditorViewModel: ObservableObject {
  @Published var lessons: [Lesson] = []
  @Published var isLoading: Bool = false
  @Published var isSaving: Bool = false
  @Published var errorMessage: String?

  func load(programId: UUID) async {
    guard !self.isLoading else { return }
    self.isLoading = true
    self.errorMessage = nil

    do {
      let fetchedLessons = try await RehabService.lessons(for: programId)
      self.lessons = fetchedLessons
      print("PTProgramEditorViewModel: fetched \(fetchedLessons.count) lessons for program \(programId)")
    } catch {
      self.errorMessage = error.localizedDescription
      print("PTProgramEditorViewModel load error: \(error)")
    }

    self.isLoading = false
  }

  func updateParams(lessonId: UUID, params: [String: Any]) async {
    await performSave {
      try await RehabService.updateLessonParams(lessonId: lessonId, params: params)
      print("PTProgramEditorViewModel: updated params for \(lessonId)")
    }
  }

  func move(lessonId: UUID, to newIndex: Int) async {
    await performSave {
      try await RehabService.updateLessonOrder(lessonId: lessonId, newOrderIndex: newIndex)
      print("PTProgramEditorViewModel: moved \(lessonId) to \(newIndex)")
    }
  }

  // MARK: - Helpers

  private func performSave(_ operation: @escaping () async throws -> Void) async {
    guard !self.isSaving else { return }
    self.isSaving = true
    self.errorMessage = nil

    do {
      try await operation()
    } catch {
      self.errorMessage = error.localizedDescription
      print("PTProgramEditorViewModel save error: \(error)")
    }

    self.isSaving = false
  }
}

