import SwiftUI
import Combine   // ← needed for ObservableObject & @Published

enum Route: Hashable {
    case welcome
    case createAccount
    case ptCreateAccount
    case pairDevice
    case calibrateDevice(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil)
    case allSet
    case ptDetail
    case home
    case homeSubCategory
    case rehabOverview
    case journeyMap
    case patientSettings
    case directionsView1(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil)
    case directionsView2(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil)
    case lesson(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil)
    case assessment(lessonId: UUID?)
    case completion(lessonId: UUID?)
    case ptSettings
    case patientList
    case ptPatientDetail(patientProfileId: UUID)
    case ptCategorySelect(patientProfileId: UUID)
    case ptInjurySelect(patientProfileId: UUID)
    case ptJourneyMap(patientProfileId: UUID, planId: UUID?)
    case ptLessonAnalytics(lessonTitle: String, lessonId: UUID?, patientProfileId: UUID?)
    case messaging(ptProfileId: UUID, patientProfileId: UUID, otherPartyName: String, isPT: Bool)
}

final class Router: ObservableObject {   // class + ObservableObject
    @Published var path = NavigationPath()
    @Published var lastRouteWithoutAnimation: Route? = nil

    func go(_ r: Route) {
        lastRouteWithoutAnimation = nil
        path.append(r)
    }
    
    func goWithoutAnimation(_ r: Route) {
        lastRouteWithoutAnimation = r
        // Use both withAnimation(nil) and withTransaction for maximum reliability
        withAnimation(nil) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                path.append(r)
            }
        }
        // Clear the flag after navigation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if self.lastRouteWithoutAnimation == r {
                self.lastRouteWithoutAnimation = nil
            }
        }
    }

    func reset(to r: Route = .welcome) {
        lastRouteWithoutAnimation = nil
        path = .init()
        path.append(r)
    }
    
    func isTabBarRoute(_ route: Route) -> Bool {
        switch route {
        case .ptDetail, .journeyMap, .patientSettings, .ptSettings, .patientList:
            return true
        default:
            return false
        }
    }
}
