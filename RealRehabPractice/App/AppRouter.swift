import SwiftUI
import Combine   // ← needed for ObservableObject & @Published

enum Route: Hashable {
    case welcome
    case selectSignUp
    case createAccount
    case ptCreateAccount
    case pairDevice
    case calibrateDevice
    case allSet
    case ptDetail
    case home
    case homeSubCategory
    case rehabOverview
    case journeyMap
    case patientSettings
    case lesson
    case completion
    case login
    case ptSettings
    case patientList
    case ptPatientDetail(patientProfileId: UUID)
    case ptCategorySelect(patientProfileId: UUID)
    case ptInjurySelect(patientProfileId: UUID)
    case ptJourneyMap(patientProfileId: UUID)
}

final class Router: ObservableObject {   // class + ObservableObject
    @Published var path = NavigationPath()

    func go(_ r: Route) { path.append(r) }

    func reset(to r: Route = .welcome) {
        path = .init()
        path.append(r)
    }
}
