import Combine
import Foundation
import Supabase

@MainActor
final class PatientDashboardViewModel: ObservableObject {
  struct ExerciseParams: Equatable {
    var reps: Int?
    var restSeconds: Int?
    var holdSeconds: Int?
  }

  @Published var programTitle: String = ""
  @Published var lessons: [Lesson] = []
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?

  func load() async {
    guard !self.isLoading else { return }
    self.isLoading = true
    self.errorMessage = nil

    do {
      let assignment = try await RehabService.myActiveAssignment()
      if let program = try await RehabService.program(id: assignment.program_id) {
        self.programTitle = program.title
      } else {
        self.programTitle = "My Rehab Program"
      }

      let fetchedLessons = try await RehabService.lessons(for: assignment.program_id)
      self.lessons = fetchedLessons

      print("PatientDashboardViewModel: loaded \(fetchedLessons.count) lessons")
    } catch {
      self.errorMessage = error.localizedDescription
      print("PatientDashboardViewModel error: \(error)")
    }

    self.isLoading = false
  }

  // MARK: - Helpers

  func exerciseParams(for lesson: Lesson) -> ExerciseParams {
    guard let params = lesson.params else {
      return ExerciseParams()
    }

    func value(for key: String) -> Int? {
      guard let json = params[key] else { return nil }
      switch json {
      case .number(let number):
        return Int(number)
      case .string(let string):
        return Int(string)
      case .bool(let bool):
        return bool ? 1 : 0
      default:
        return nil
      }
    }

    return ExerciseParams(
      reps: value(for: "reps"),
      restSeconds: value(for: "rest_seconds"),
      holdSeconds: value(for: "hold")
    )
  }
}


