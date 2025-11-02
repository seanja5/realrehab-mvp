//
//  RealRehabPracticeApp.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 10/28/25.
//

import SwiftUI

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
                        case .pairDeviceSearching: PairDeviceSearchingView()
                        case .pairDeviceFound: PairDeviceFoundView()
                        case .calibrateDevice: CalibrateDeviceView()
                        case .allSet: AllSetView()
                        case .home: HomeView()
                        case .homeSubCategory: HomeSubCategoryView()
                        case .rehabOverview: RehabOverviewView()
                        case .journeyMap: JourneyMapView()
                        case .lesson: LessonView()                // ← single lesson screen
                        case .completion: CompletionView()
                        }
                    }
            }
            .environmentObject(router)
            .preferredColorScheme(.light)   // <- force Light mode app-wide
        }
    }
}
