import Combine
import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
  @Published var email: String = ""
  @Published var password: String = ""
  @Published var firstName: String = ""
  @Published var lastName: String = ""
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?

  func signUp() async {
    await run {
      try await AuthService.signUp(email: self.email, password: self.password)
      try await AuthService.signIn(email: self.email, password: self.password)
      try await AuthService.ensureProfile(
        defaultRole: "patient",
        firstName: self.firstName,
        lastName: self.lastName
      )
      try self.logCurrentUser()
    }
  }

  func signIn() async {
    await run {
      try await AuthService.signIn(email: self.email, password: self.password)
      try self.logCurrentUser()
    }
  }

  func signOut() async {
    await run {
      try await AuthService.signOut()
      print("AuthViewModel.signOut: user signed out")
    }
  }

  func myProfile() async -> Profile? {
    do {
      let profile = try await AuthService.myProfile()
      if let profile {
        print("AuthViewModel.myProfile: loaded profile for \(profile.user_id)")
      }
      return profile
    } catch {
      await self.setError(error)
      return nil
    }
  }

  // MARK: - Helpers

  private func run(_ operation: @escaping () async throws -> Void) async {
    guard !self.isLoading else { return }
    self.isLoading = true
    self.errorMessage = nil
    do {
      try await operation()
    } catch {
      await self.setError(error)
    }
    self.isLoading = false
  }

  private func setError(_ error: Error) async {
    self.errorMessage = error.localizedDescription
    print("AuthViewModel error: \(error)")
  }

  private func logCurrentUser() throws {
    let userId = try AuthService.currentUserId()
    print("AuthViewModel: current user \(userId)")
  }
}

