import SwiftUI
import UIKit

private struct ScoredLesson: Identifiable {
    let id: UUID      // lesson_id
    let title: String
    let score: Int
}

struct PatientDetailView: View {
    let patientProfileId: UUID
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: SessionContext
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var vm = PTPatientsViewModel()
    @State private var notes: String = ""
    @State private var currentPlan: RehabService.PlanRow? = nil
    @State private var patient: PTService.SimplePatient? = nil
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String? = nil
    @State private var notesSaveTask: Task<Void, Never>? = nil
    @State private var isKeyboardVisible = false
    @State private var showOfflineBanner = false
    @State private var unreadMessageCount = 0
    @State private var patientStatus: PatientStatus = .neutral
    @State private var lessonScores: [ScoredLesson] = []
    @State private var isLoadingScores = false
    @State private var isPatientCardExpanded = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OfflineStaleBanner(showBanner: !networkMonitor.isOnline && showOfflineBanner)
                    if isLoading || (patient == nil && errorMessage == nil) {
                        skeletonContent
                    } else {
                        VStack(alignment: .leading, spacing: RRSpace.section) {

                            // — Patient card (name, phone, email, status chip; tap to reveal metadata)
                            patientCard

                            sectionDivider

                            // — Current Rehab Plan
                            sectionHeader("Current Rehab Plan")
                            VStack(alignment: .leading, spacing: RRSpace.stack) {
                                if let plan = currentPlan, let nodes = plan.nodes, !nodes.isEmpty {
                                    Button {
                                        router.go(.ptJourneyMap(patientProfileId: patientProfileId, planId: plan.id))
                                    } label: {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 240)
                                            .overlay(
                                                Image("aclrehab")
                                                    .resizable()
                                                    .scaledToFill()
                                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)

                                    Text("\(plan.injury) Rehab")
                                        .font(.rrBody)
                                        .foregroundStyle(.primary)
                                        .padding(.top, 10)
                                        .padding(.bottom, 8)

                                    SecondaryButton(title: "Change Rehab Plan") {
                                        router.go(.ptCategorySelect(patientProfileId: patientProfileId))
                                    }
                                } else {
                                    SecondaryButton(title: "Select Rehab Plan") {
                                        router.go(.ptCategorySelect(patientProfileId: patientProfileId))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                            // — Progress this week + exercise performance
                            if let plan = currentPlan, let nodes = plan.nodes, !nodes.isEmpty {
                                RecoveryChartWeekView(patientProfileId: patientProfileId)
                                    .padding(.top, 16)

                                ActivityConsistencyCard(completedDays: 0)
                                    .padding(.top, 8)

                                exercisePerformanceSection
                            }

                            sectionDivider

                            // — Notes
                            sectionHeader("Notes")
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                                .overlay(
                                    ZStack(alignment: .topLeading) {
                                        if notes.isEmpty {
                                            Text("Tap to add notes…")
                                                .font(.rrBody)
                                                .foregroundStyle(.secondary)
                                                .padding(16)
                                        }
                                        TextEditor(text: $notes)
                                            .font(.rrBody)
                                            .padding(12)
                                            .scrollContentBackground(.hidden)
                                            .background(Color.clear)
                                    }
                                )
                                .frame(minHeight: 180)
                                .padding(.horizontal, 16)

                            sectionDivider

                            // — Access Code
                            if let accessCode = patient?.access_code, !accessCode.isEmpty {
                                sectionHeader("Access Code")
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                                    .overlay(
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Share this code with your patient to link their account:")
                                                .font(.rrCaption)
                                                .foregroundStyle(.secondary)
                                            Text(accessCode)
                                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.primary)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .padding(.vertical, 8)
                                        }
                                        .padding(16)
                                    )
                                    .frame(minHeight: 100)
                                    .padding(.horizontal, 16)

                                if patient?.profile_id == nil {
                                    SecondaryButton(title: "Invite Patient") {
                                        ShareSheetHelper.presentShareSheet(code: accessCode)
                                    }
                                    .padding(.horizontal, 16)
                                }

                                sectionDivider
                            }

                            // — Danger Zone
                            Text("Remove")
                                .font(.rrTitle)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)

                            DestructiveButton(title: "Remove Patient") {
                                showDeleteConfirmation = true
                            }
                            .padding(.horizontal, 16)

                            Spacer(minLength: 24)
                        }
                    }
                }
                .padding(.bottom, isKeyboardVisible ? 16 : 80)
            }

            if !isKeyboardVisible {
                VStack {
                    Spacer()
                    PTTabBar(selected: .dashboard) { tab in
                        switch tab {
                        case .dashboard:
                            router.goWithoutAnimation(.patientList)
                        case .settings:
                            router.goWithoutAnimation(.ptSettings)
                        }
                    }
                    .background(Color.white)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .rrPageBackground()
        .navigationTitle("My Patient")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .swipeToGoBack(onBack: { router.reset(to: .patientList) })
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton { router.reset(to: .patientList) }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let ptId = session.ptProfileId, let patient = patient {
                    Button {
                        let name = [patient.first_name, patient.last_name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                        router.go(.messaging(ptProfileId: ptId, patientProfileId: patientProfileId, otherPartyName: name.isEmpty ? "Patient" : name, isPT: true))
                    } label: {
                        MessageIconWithBadge(unreadCount: unreadMessageCount)
                    }
                }
            }
        }
        .task {
            vm.setPTProfileId(session.ptProfileId)
            await loadPatientData(patientProfileId: patientProfileId, forceRefresh: false)
            if let ptId = session.ptProfileId {
                unreadMessageCount = (try? await MessagingService.getUnreadCount(ptProfileId: ptId, patientProfileId: patientProfileId, isPT: true)) ?? 0
            }
        }
        .refreshable {
            await loadPatientData(patientProfileId: patientProfileId, forceRefresh: true)
        }
        .onChange(of: notes) { oldValue, newValue in
            notesSaveTask?.cancel()
            notesSaveTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if !Task.isCancelled {
                    await saveNotes()
                }
            }
        }
        .alert("Delete Patient", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await vm.delete(patientProfileId: patientProfileId)
                    router.reset(to: .patientList)
                }
            }
        } message: {
            Text("This will remove this patient from your list. This action cannot be undone.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear {
            errorMessage = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) { isKeyboardVisible = false }
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.rrTitle)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    // MARK: - Patient Card

    private var patientCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Always-visible row: name, phone, email + status chip
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(patientName)
                        .font(.rrTitle)
                        .foregroundStyle(.primary)
                    Text("Phone: \((patient?.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "--" : (patient?.phone ?? "--"))")
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                    Text("Email: \((patient?.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "--" : (patient?.email ?? "--"))")
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 8) {
                    if patientStatus != .neutral {
                        Text(patientStatus.label)
                            .font(.rrCaption.bold())
                            .foregroundStyle(patientStatus.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(patientStatus.color.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    Image(systemName: isPatientCardExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)

            // Expandable metadata strip
            if isPatientCardExpanded {
                HStack(spacing: 0) {
                    metaCellView(label: "Date of Birth", value: formattedDOB(patient?.date_of_birth))
                    Rectangle().fill(Color.black.opacity(0.07)).frame(width: 1, height: 36)
                    metaCellView(label: "Gender", value: patient?.gender?.capitalized ?? "--")
                    Rectangle().fill(Color.black.opacity(0.07)).frame(width: 1, height: 36)
                    metaCellView(label: "Last PT Visit", value: formattedDOB(patient?.last_pt_visit))
                    Rectangle().fill(Color.black.opacity(0.07)).frame(width: 1, height: 36)
                    metaCellView(label: "Surgery Date", value: formattedDOB(patient?.surgery_date))
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 14)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .overlay(
                    LinearGradient(
                        colors: [.clear, patientStatus.color.opacity(patientStatus == .neutral ? 0 : 0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .allowsHitTesting(false)
                )
                .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 6)
                .shadow(color: Color.brandDarkBlue.opacity(0.07), radius: 6, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isPatientCardExpanded.toggle()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, RRSpace.pageTop)
    }

    private func metaCellView(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.rrCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.rrCallout.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - Exercise Performance Section

    @ViewBuilder
    private var exercisePerformanceSection: some View {
        if !lessonScores.isEmpty || isLoadingScores {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Exercise Performance")
                    .padding(.top, 8)

                if isLoadingScores {
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color(white: 0.88))
                                    .frame(width: 64, height: 64)
                                    .shimmer()
                                SkeletonBlock(width: 56, height: 11)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 4)
                    )
                    .padding(.horizontal, 16)
                } else {
                    let sorted = lessonScores.sorted { $0.score > $1.score }
                    let top3 = Array(sorted.prefix(3))
                    let topIds = Set(top3.map { $0.id })
                    let worst3 = Array(lessonScores.sorted { $0.score < $1.score }.filter { !topIds.contains($0.id) }.prefix(3))

                    scoreRowView(subtitle: "Top Performers", items: top3)

                    if !worst3.isEmpty {
                        scoreRowView(subtitle: "Needs Attention", items: worst3)
                    }
                }
            }
        }
    }

    private func scoreRowView(subtitle: String, items: [ScoredLesson]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(subtitle)
                .font(.rrCaption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            HStack(spacing: 0) {
                ForEach(items) { item in
                    scoreCircleButton(item: item)
                        .frame(maxWidth: .infinity)
                }
                if items.count < 3 {
                    ForEach(0..<(3 - items.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 4)
                    .shadow(color: Color.brandDarkBlue.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
        }
    }

    private func scoreCircleButton(item: ScoredLesson) -> some View {
        let color = scoreColor(item.score)
        return Button {
            router.go(.ptLessonAnalytics(lessonTitle: item.title, lessonId: item.id, patientProfileId: patientProfileId))
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.15), lineWidth: 5)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(item.score) / 100.0)
                        .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    Text("\(item.score)")
                        .font(.rrTitle.bold())
                        .foregroundStyle(color)
                }
                Text(item.title)
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 72)
            }
        }
        .buttonStyle(.plain)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return PatientStatus.onTrack.color }
        if score >= 70 { return PatientStatus.fallingBehind.color }
        return PatientStatus.needsHelp.color
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: RRSpace.section) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                .overlay(
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 22).frame(width: 180)
                        SkeletonBlock(height: 16).frame(width: 200)
                        SkeletonBlock(height: 16).frame(width: 160)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                )
                .frame(minHeight: 110)
                .padding(.horizontal, 16)
                .padding(.top, RRSpace.pageTop)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBlock(width: 100, height: 14)
                    SkeletonBlock(width: 80, height: 14)
                }
                Spacer(minLength: 16)
                VStack(alignment: .trailing, spacing: 6) {
                    SkeletonBlock(width: 120, height: 14)
                    SkeletonBlock(width: 110, height: 14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(height: 1)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: RRSpace.stack) {
                SkeletonBlock(width: 160, height: 18).padding(.horizontal, 16)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .padding(.horizontal, 16)
                    .shimmer()
                SkeletonBlock(width: 120, height: 16)
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
            }

            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(height: 1)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: RRSpace.stack) {
                SkeletonBlock(width: 60, height: 18).padding(.horizontal, 16)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.88))
                    .frame(minHeight: 180)
                    .padding(.horizontal, 16)
                    .shimmer()
            }

            Spacer(minLength: 24)
        }
    }

    // MARK: - Helpers

    private var patientName: String {
        if let patient = patient {
            return "\(patient.first_name) \(patient.last_name)"
        }
        return "My Patient"
    }

    private func formattedDOB(_ dateString: String?) -> String {
        guard let dateStr = dateString, !dateStr.isEmpty else { return "--" }
        if let date = Date.fromDateOnlyString(dateStr) {
            return dateFormatter.string(from: date)
        }
        return dateStr
    }

    private func loadPatientData(patientProfileId: UUID, forceRefresh: Bool = false) async {
        guard let ptProfileId = session.ptProfileId else {
            errorMessage = "PT profile not available"
            debugLog("❌ PatientDetailView.loadPatientData: ptProfileId is nil")
            return
        }

        isLoading = true
        showOfflineBanner = false
        do {
            let (loadedPatient, patientStale) = try await PTService.getPatientForDisplay(patientProfileId: patientProfileId)
            self.patient = loadedPatient
            let (plan, planStale) = try await RehabService.currentPlanForDisplay(ptProfileId: ptProfileId, patientProfileId: patientProfileId)
            self.currentPlan = plan
            self.notes = plan?.notes ?? ""
            self.showOfflineBanner = !NetworkMonitor.shared.isOnline && (patientStale || planStale || forceRefresh)
            let dates = (try? await RehabService.getCompletionDates(patientProfileId: patientProfileId)) ?? []
            self.patientStatus = PatientStatus.compute(from: dates)

            // Load lesson performance scores
            isLoadingScores = true
            isLoading = false
            if let nodes = plan?.nodes {
                let titleMap: [UUID: String] = Dictionary(
                    uniqueKeysWithValues: nodes.compactMap { node -> (UUID, String)? in
                        guard let id = UUID(uuidString: node.id) else { return nil }
                        return (id, node.title)
                    }
                )
                let allInsights = (try? await LessonSensorInsightsService.fetchAll(patientProfileId: patientProfileId)) ?? []
                // Deduplicate by lesson_id — most recent completed session per lesson
                let byLesson = Dictionary(grouping: allInsights, by: \.lesson_id)
                    .compactMapValues { rows in
                        rows.sorted { ($0.completed_at ?? .distantPast) > ($1.completed_at ?? .distantPast) }.first
                    }
                self.lessonScores = byLesson.compactMap { lessonId, row in
                    let title = titleMap[lessonId] ?? "Lesson"
                    let score = PatientLessonScore.compute(insights: row).score
                    return ScoredLesson(id: lessonId, title: title, score: score)
                }
            }
            isLoadingScores = false
        } catch {
            if error is CancellationError || Task.isCancelled {
                isLoading = false
                isLoadingScores = false
                return
            }
            if patient == nil && currentPlan == nil {
                debugLog("❌ PatientDetailView.loadPatientData error: \(error)")
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
        isLoadingScores = false
    }

    private func saveNotes() async {
        guard let ptProfileId = session.ptProfileId else {
            debugLog("❌ PatientDetailView.saveNotes: ptProfileId is nil")
            return
        }
        do {
            try await RehabService.updatePlanNotes(
                ptProfileId: ptProfileId,
                patientProfileId: patientProfileId,
                notes: notes.isEmpty ? nil : notes
            )
            debugLog("✅ PatientDetailView: saved notes")
        } catch {
            if error is CancellationError || Task.isCancelled { return }
            debugLog("❌ PatientDetailView.saveNotes error: \(error)")
            errorMessage = "Failed to save notes: \(error.localizedDescription)"
        }
    }
}
