import SwiftUI
import Combine

struct PTDetailView: View {
    @EnvironmentObject var router: Router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var vm = PatientPTViewModel()
    @State private var scheduleSlots: [ScheduleService.ScheduleSlot] = []
    @State private var unreadMessageCount = 0
    @State private var isPTCardExpanded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: RRSpace.section) {
                    if vm.isLoading && vm.name.isEmpty {
                        skeletonContent
                    } else {
                    ptInfoCard

                    Divider()
                        .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        Text("Current Rehab Plan")
                            .font(.rrTitle)
                            .padding(.horizontal, 16)

                        if vm.hasRehabPlan {
                            Button {
                                router.go(.journeyMap)
                            } label: {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(maxWidth: horizontalSizeClass == .regular ? 360 : .infinity)
                                    .frame(height: horizontalSizeClass == .regular ? 160 : 240)
                                    .overlay(
                                        Image("aclrehab")
                                            .resizable()
                                            .scaledToFill()
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                    )
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: horizontalSizeClass == .regular ? .infinity : nil)
                            .padding(.horizontal, 16)

                            Text("ACL Rehab")
                                .font(.rrBody)
                                .foregroundStyle(.primary)
                                .padding(.top, 10)
                                .padding(.horizontal, 16)

                            Rectangle()
                                .fill(Color.black.opacity(0.12))
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            // My Schedule visualizer
                            ScheduleVisualizerView(slots: scheduleSlots)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            SecondaryButton(title: scheduleSlots.isEmpty ? "Create a Schedule" : "Edit Schedule") {
                                router.go(.rehabOverview)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                            // Progress this week section
                            RecoveryChartWeekView()
                                .padding(.top, 16)

                            // Activity section - show 1 day for patient view
                            ActivityConsistencyCard(completedDays: 1)
                                .padding(.top, 8)
                        } else {
                            Text("No rehab plan assigned")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 24)
                    }
                }
                .padding(.bottom, 120)
            }

            PatientTabBar(
                selected: .dashboard,
                onSelect: { tab in
                    switch tab {
                    case .dashboard:
                        break
                    case .journey:
                        router.goWithoutAnimation(.journeyMap)
                    case .settings:
                        router.goWithoutAnimation(.patientSettings)
                    }
                },
                onAddTapped: {
                    router.go(.pairDevice)
                }
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .rrPageBackground()
        .navigationTitle("My Physical Therapist")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let ptId = vm.ptProfileId, let patId = vm.patientProfileId, !vm.name.isEmpty {
                    Button {
                        router.go(.messaging(ptProfileId: ptId, patientProfileId: patId, otherPartyName: vm.name, isPT: false))
                    } label: {
                        MessageIconWithBadge(unreadCount: unreadMessageCount)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                BluetoothStatusIndicator()
            }
        }
        .task {
            await vm.load()
            await loadSchedule()
            if let ptId = vm.ptProfileId, let patId = vm.patientProfileId {
                unreadMessageCount = (try? await MessagingService.getUnreadCount(ptProfileId: ptId, patientProfileId: patId, isPT: false)) ?? 0
            }
        }
        .refreshable {
            await vm.load(forceRefresh: true)
            await loadSchedule()
            if let ptId = vm.ptProfileId, let patId = vm.patientProfileId {
                unreadMessageCount = (try? await MessagingService.getUnreadCount(ptProfileId: ptId, patientProfileId: patId, isPT: false)) ?? 0
            }
        }
        .onAppear {
            Task { await loadSchedule() }
        }
        .bluetoothPopupOverlay()
    }

    // MARK: - PT Info Card (expandable)

    private var ptInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Always-visible row: name, phone, email + chevron
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.name.isEmpty ? "My Physical Therapist" : vm.name)
                        .font(.rrTitle)
                        .foregroundStyle(.primary)
                    Text("Phone: \(vm.phone.isEmpty ? "—" : vm.phone)")
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                    Text("Email: \(vm.email.isEmpty ? "—" : vm.email)")
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isPTCardExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(16)

            // Expandable practice info strip
            if isPTCardExpanded {
                let hasCredentials = !vm.credentialType.isEmpty || !vm.licenseNumber.isEmpty || !vm.npiNumber.isEmpty
                let hasPracticeInfo = !vm.practiceName.isEmpty || !vm.practiceAddress.isEmpty || !vm.specialization.isEmpty
                if hasCredentials || hasPracticeInfo {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(Color.rrBorder)
                            .frame(height: 1)
                            .padding(.horizontal, 16)

                        // Row 1: Credential Type | License # | NPI
                        if hasCredentials {
                            HStack(spacing: 0) {
                                if !vm.credentialType.isEmpty {
                                    ptMetaCellView(label: "Credential", value: vm.credentialType)
                                    Rectangle().fill(Color.rrBorder).frame(width: 1, height: 36)
                                }
                                if !vm.licenseNumber.isEmpty {
                                    ptMetaCellView(label: "License #", value: vm.licenseNumber)
                                    Rectangle().fill(Color.rrBorder).frame(width: 1, height: 36)
                                }
                                if !vm.npiNumber.isEmpty {
                                    ptMetaCellView(label: "NPI", value: vm.npiNumber)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 10)
                            .padding(.bottom, hasPracticeInfo ? 0 : 14)
                        }

                        // Divider between rows
                        if hasCredentials && hasPracticeInfo {
                            Rectangle()
                                .fill(Color.rrBorder)
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                        }

                        // Row 2: Practice Name | Practice Address | Specialty
                        if hasPracticeInfo {
                            HStack(spacing: 0) {
                                if !vm.practiceName.isEmpty {
                                    ptMetaCellView(label: "Practice", value: vm.practiceName)
                                    Rectangle().fill(Color.rrBorder).frame(width: 1, height: 36)
                                }
                                if !vm.practiceAddress.isEmpty {
                                    ptMetaCellView(label: "Address", value: vm.practiceAddress)
                                    Rectangle().fill(Color.rrBorder).frame(width: 1, height: 36)
                                }
                                if !vm.specialization.isEmpty {
                                    ptMetaCellView(label: "Specialty", value: vm.specialization)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, hasCredentials ? 0 : 10)
                            .padding(.bottom, 14)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(Color.rrBorder)
                            .frame(height: 1)
                            .padding(.horizontal, 16)

                        Text("No practice information on file")
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.rrSurface)
                .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 6)
                .shadow(color: Color.brandDarkBlue.opacity(0.07), radius: 6, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isPTCardExpanded.toggle()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, RRSpace.pageTop)
    }

    private func ptMetaCellView(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.rrCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.rrCallout.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: RRSpace.section) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.rrSurface)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                .overlay(
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 180, height: 22)
                        SkeletonBlock(width: 200, height: 16)
                        SkeletonBlock(width: 160, height: 16)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                )
                .frame(minHeight: 110)
                .padding(.horizontal, 16)
                .padding(.top, RRSpace.pageTop)
            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(height: 1)
                .padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: RRSpace.stack) {
                SkeletonBlock(width: 160, height: 18)
                    .padding(.horizontal, 16)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.rrSkeleton)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .padding(.horizontal, 16)
                    .shimmer()
            }
            .padding(.top, 4)
            Spacer(minLength: 24)
        }
    }

    private func loadSchedule() async {
        do {
            guard let profile = try await AuthService.myProfile() else { return }
            let patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
            let slots = try await ScheduleService.getSchedule(patientProfileId: patientProfileId)
            await MainActor.run {
                scheduleSlots = slots
            }
        } catch {
            scheduleSlots = []
        }
    }
}
