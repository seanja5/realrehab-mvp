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
    @StateObject private var pendingLinkStore = PendingLinkStore()
    @StateObject private var invitedStore = InvitedPatientsStore()
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
                                case .calibrateDevice(let reps, let restSec, let lessonId): CalibrateDeviceView(reps: reps, restSec: restSec, lessonId: lessonId)
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
                                case .assessment(let lessonId): AssessmentView(lessonId: lessonId)
                                case .completion(let lessonId): CompletionView(lessonId: lessonId)
                                case .ptSettings: PTSettingsView()
                                case .patientList: PatientListView()
                                case .ptPatientDetail(let patientProfileId): PatientDetailView(patientProfileId: patientProfileId)
                                case .ptCategorySelect(let patientProfileId): CategorySelectView(patientProfileId: patientProfileId)
                                case .ptInjurySelect(let patientProfileId): InjurySelectView(patientProfileId: patientProfileId)
                                case .ptJourneyMap(let patientProfileId, let planId): PTJourneyMapView(patientProfileId: patientProfileId, planId: planId)
                                case .ptLessonAnalytics(let lessonTitle, let lessonId, let patientProfileId):
                                    if let lid = lessonId, let pid = patientProfileId {
                                        LessonAnalyticsView(lessonTitle: lessonTitle, lessonId: lid, patientProfileId: pid)
                                    } else {
                                        AnalyticsView(lessonTitle: lessonTitle, lessonId: lessonId, patientProfileId: patientProfileId)
                                    }
                                case .messaging(let ptProfileId, let patientProfileId, let otherPartyName, let isPT):
                                    MessagingView(ptProfileId: ptProfileId, patientProfileId: patientProfileId, otherPartyName: otherPartyName, isPT: isPT)
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
            .environmentObject(pendingLinkStore)
            .environmentObject(invitedStore)
            .onOpenURL { url in
                guard let code = parseAccessCode(from: url) else { return }
                pendingLinkStore.setCode(code)
                if session.profileId != nil && session.ptProfileId == nil {
                    router.reset(to: .patientSettings)
                } else if session.profileId == nil {
                    router.reset(to: .createAccount)
                }
            }
            .task {
                // Use resolveSessionForLaunch: checks cache first (works offline after app restart)
                let bootstrap = await AuthService.resolveSessionForLaunch()
                if let bootstrap = bootstrap {
                    session.profileId = bootstrap.profileId
                    session.ptProfileId = bootstrap.ptProfileId
                    print("✅ Session restored: profile=\(bootstrap.profileId.uuidString), pt_profile=\(bootstrap.ptProfileId?.uuidString ?? "nil"), role=\(bootstrap.role)")
                    switch bootstrap.role {
                    case "pt":
                        router.reset(to: .patientList)
                    case "patient":
                        router.reset(to: .ptDetail)
                    default:
                        break
                    }
                }
                await OutboxSyncManager.shared.processQueueIfOnline()
                // Handle deep link after cold start: if code was set by onOpenURL before session existed, navigate now
                if pendingLinkStore.code != nil {
                    if bootstrap?.role == "patient" {
                        router.reset(to: .patientSettings)
                    } else {
                        router.reset(to: .createAccount)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scheduleReminderTapped)) { _ in
                router.reset(to: .journeyMap)
            }
            .onReceive(NotificationCenter.default.publisher(for: .ptSessionCompleteTapped)) { notification in
                if let id = notification.userInfo?["patientProfileId"] as? UUID {
                    router.reset(to: .ptPatientDetail(patientProfileId: id))
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await rescheduleRemindersIfNeeded()
                        await OutboxSyncManager.shared.processQueueIfOnline()
                        await checkPTSessionCompleteIfNeeded()
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

    private func parseAccessCode(from url: URL) -> String? {
        guard url.scheme == "realrehab", url.host == "link" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }

    private func checkPTSessionCompleteIfNeeded() async {
        do {
            guard let profile = try await AuthService.myProfile(), profile.role == "pt" else { return }
            await PTSessionCompleteNotifier.checkAndNotify()
        } catch { }
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
