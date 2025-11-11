import Foundation
import Combine

final class SessionContext: ObservableObject {
  @Published var profileId: UUID?
  @Published var ptProfileId: UUID?
}

