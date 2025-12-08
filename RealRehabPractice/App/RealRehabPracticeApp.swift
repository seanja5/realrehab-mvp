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
    @StateObject private var session = SessionContext()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                NavigationStack(path: $router.path) {
                    WelcomeView()
                        .navigationDestination(for: Route.self) { route in
                            Group {
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
                                case .directionsView1(let reps, let restSec): DirectionsView1(reps: reps, restSec: restSec)
                                case .directionsView2(let reps, let restSec): DirectionsView2(reps: reps, restSec: restSec)
                                case .lesson(let reps, let restSec): LessonView(reps: reps, restSec: restSec)                // ← single lesson screen
                                case .completion: CompletionView()
                                case .ptSettings: PTSettingsView()
                                case .patientList: PatientListView()
                                case .ptPatientDetail(let patientProfileId): PatientDetailView(patientProfileId: patientProfileId)
                                case .ptCategorySelect(let patientProfileId): CategorySelectView(patientProfileId: patientProfileId)
                                case .ptInjurySelect(let patientProfileId): InjurySelectView(patientProfileId: patientProfileId)
                                case .ptJourneyMap(let patientProfileId, let planId): PTJourneyMapView(patientProfileId: patientProfileId, planId: planId)
                                }
                            }
                            .id(route)
                            .transaction { transaction in
                                if router.lastRouteWithoutAnimation == route {
                                    transaction.disablesAnimations = true
                                }
                            }
                        }
                }
                .transaction { transaction in
                    if router.lastRouteWithoutAnimation != nil {
                        transaction.disablesAnimations = true
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
            .environmentObject(session)
            .task {
                do {
                    let ids = try await AuthService.resolveIdsForCurrentUser()
                    session.profileId = ids.profileId
                    session.ptProfileId = ids.ptProfileId
                    print("✅ Resolved IDs: profile=\(ids.profileId?.uuidString ?? "nil"), pt_profile=\(ids.ptProfileId?.uuidString ?? "nil")")
                } catch {
                    print("❌ Resolve IDs error: \(error)")
                }
            }
            .preferredColorScheme(.light)   // <- force Light mode app-wide
        }
    }
}
