//
//  RealRehabPracticeApp.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 10/28/25.
//

import SwiftUI
import UIKit
import UserNotifications

@main
struct RealRehabPracticeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var router = Router()
    @StateObject private var session = SessionContext()
    @StateObject private var networkMonitor = NetworkMonitor.shared

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate()
    }

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
                                case .directionsView1(let reps, let restSec, let lessonId): DirectionsView1(reps: reps, restSec: restSec, lessonId: lessonId)
                                case .directionsView2(let reps, let restSec, let lessonId): DirectionsView2(reps: reps, restSec: restSec, lessonId: lessonId)
                                case .lesson(let reps, let restSec, let lessonId): LessonView(reps: reps, restSec: restSec, lessonId: lessonId)
                                case .assessment: AssessmentView()
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
                    guard let profileId = ids.profileId else { return }
                    session.profileId = profileId
                    session.ptProfileId = ids.ptProfileId
                    print("✅ Resolved IDs: profile=\(profileId.uuidString), pt_profile=\(ids.ptProfileId?.uuidString ?? "nil")")
                    let (_, role) = try await AuthService.myProfileIdAndRole()
                    switch role {
                    case "pt":
                        router.reset(to: .patientList)
                    case "patient":
                        router.reset(to: .ptDetail)
                    default:
                        break
                    }
                } catch {
                    print("❌ Resolve IDs error (no session): \(error)")
                }
                await OutboxSyncManager.shared.processQueueIfOnline()
            }
            .onReceive(NotificationCenter.default.publisher(for: .scheduleReminderTapped)) { _ in
                router.reset(to: .journeyMap)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await rescheduleRemindersIfNeeded()
                        await OutboxSyncManager.shared.processQueueIfOnline()
                    }
                }
            }
            .onChange(of: networkMonitor.isOnline) { _, isOnline in
                if isOnline {
                    Task { await OutboxSyncManager.shared.processQueueIfOnline() }
                }
            }
            .preferredColorScheme(.light)   // <- force Light mode app-wide
        }
    }

    private func rescheduleRemindersIfNeeded() async {
        do {
            guard let profile = try await AuthService.myProfile(), profile.role == "patient" else { return }
            let patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
            let enabled = try await PatientService.getScheduleRemindersEnabled(patientProfileId: patientProfileId)
            guard enabled else { return }
            let slots = try await ScheduleService.getSchedule(patientProfileId: patientProfileId)
            guard !slots.isEmpty else { return }
            let granted = await NotificationManager.authorizationStatus() == .authorized
            guard granted else { return }
            await NotificationManager.scheduleScheduleReminders(slots: slots, firstName: profile.first_name)
        } catch {
            // Ignore - user may not be signed in or not a patient
        }
    }
}
