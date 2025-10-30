import SwiftUI
import Combine   // ← needed for ObservableObject & @Published

enum Route: Hashable {
    case welcome
    case createAccount
    case pairDeviceSearching
    case pairDeviceFound
    case calibrateDevice
    case allSet
    case home
    case homeSubCategory
    case rehabOverview
    case journeyMap
    case lesson
    case completion
}

final class Router: ObservableObject {   // class + ObservableObject
    @Published var path = NavigationPath()

    func go(_ r: Route) { path.append(r) }

    func reset(to r: Route = .welcome) {
        path = .init()
        path.append(r)
    }
}
