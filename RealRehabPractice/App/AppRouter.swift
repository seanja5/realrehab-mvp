import SwiftUI
import Combine   // ← needed for ObservableObject & @Published

enum Route: Hashable {
    case welcome
    case createAccount
    case pairDevice
    case calibrateDevice
    case allSet
    case ptDetail
    case home
    case homeSubCategory
    case rehabOverview
    case journeyMap
    case lesson
    case completion
    case selectLogin
    case patientLogin
    case ptLogin
    case patientList
    case ptPatientDetail
    case ptCategorySelect
    case ptInjurySelect
    case ptJourneyMap
}

final class Router: ObservableObject {   // class + ObservableObject
    @Published var path = NavigationPath()

    func go(_ r: Route) { path.append(r) }

    func reset(to r: Route = .welcome) {
        path = .init()
        path.append(r)
    }
}
