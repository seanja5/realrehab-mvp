//
//  RealRehabPracticeApp.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 10/28/25.
//

import SwiftUI
import UIKit

@main
struct RealRehabPracticeApp: App {
    @StateObject var router = Router()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                WelcomeView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .welcome: WelcomeView()
                        case .createAccount: CreateAccountView()
                        case .pairDevice: PairDeviceView()
                        case .calibrateDevice: CalibrateDeviceView()
                        case .allSet: AllSetView()
                        case .home: HomeView()
                        case .homeSubCategory: HomeSubCategoryView()
                        case .rehabOverview: RehabOverviewView()
                        case .journeyMap: JourneyMapView()
                        case .lesson: LessonView()                // ← single lesson screen
                        case .completion: CompletionView()
                        case .selectLogin: SelectLoginView()
                        case .ptLogin: PTLoginView()
                        case .patientList: PatientListView()
                        case .ptPatientDetail: PatientDetailView()
                        case .ptCategorySelect: CategorySelectView()
                        case .ptInjurySelect: InjurySelectView()
                        case .ptJourneyMap: PTJourneyMapView()
                        }
                    }
            }
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
            .environmentObject(router)
            .preferredColorScheme(.light)   // <- force Light mode app-wide
        }
    }
}
