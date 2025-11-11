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
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                NavigationStack(path: $router.path) {
                    WelcomeView()
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .welcome: WelcomeView()
                            case .selectSignUp: SelectSignUpView()
                            case .createAccount: CreateAccountView()
                            case .ptCreateAccount: PTCreateAccountView()
                            case .pairDevice: PairDeviceView()
                            case .calibrateDevice: CalibrateDeviceView()
                            case .allSet: AllSetView()
                            case .ptDetail: PTDetailView()
                            case .home: HomeView()
                            case .homeSubCategory: HomeSubCategoryView()
                            case .rehabOverview: RehabOverviewView()
                            case .journeyMap: JourneyMapView()
                            case .patientSettings: PatientSettingsView()
                            case .lesson: LessonView()                // ← single lesson screen
                            case .completion: CompletionView()
                            case .login: LoginView()
                            case .ptSettings: PTSettingsView()
                            case .patientList: PatientListView()
                            case .ptPatientDetail(let patientProfileId): PatientDetailView(patientProfileId: patientProfileId)
                            case .ptCategorySelect(let patientProfileId): CategorySelectView(patientProfileId: patientProfileId)
                            case .ptInjurySelect(let patientProfileId): InjurySelectView(patientProfileId: patientProfileId)
                            case .ptJourneyMap(let patientProfileId): PTJourneyMapView(patientProfileId: patientProfileId)
                            }
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
