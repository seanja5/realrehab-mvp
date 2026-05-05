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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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

    // Outreach banner
    @State private var outreachSent = false
    @State private var outreachBannerVisible = true
    @State private var callInitiated = false

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

                            // — Outreach text banner (only when patient is behind)
                            if (patientStatus == .fallingBehind || patientStatus == .needsHelp) && outreachBannerVisible {
                                outreachBannerView
                                    .transition(.opacity.combined(with: .move(edge: .top)))

                                sectionDivider
                            }

                            // — Current Rehab Plan
                            sectionHeader("Current Rehab Plan")
                            VStack(alignment: .leading, spacing: RRSpace.stack) {
                                if let plan = currentPlan, let nodes = plan.nodes, !nodes.isEmpty {
                                    Button {
                                        router.go(.ptJourneyMap(patientProfileId: patientProfileId, planId: plan.id))
                                    } label: {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(maxWidth: horizontalSizeClass == .regular ? 360 : .infinity)
                                            .frame(height: horizontalSizeClass == .regular ? 160 : 240)
                                            .overlay(
                                                Image("aclrehab")
                                                    .resizable()
                                                    .scaledToFill()
                                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: horizontalSizeClass == .regular ? .infinity : nil)
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
                                RecoveryChartWeekView(patientProfileId: patientProfileId, patientName: patientName)
                                    .padding(.top, 16)

                                ActivityConsistencyCard(completedDays: 0)
                                    .padding(.top, 8)

                                exercisePerformanceSection
                            }

                            sectionDivider

                            // — Notes
                            sectionHeader("Notes")
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.rrSurface)
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
                                    .fill(Color.rrSurface)
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
                    .background(Color.rrSurface)
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
        .onChange(of: patientStatus) { _, _ in
            outreachSent = false
            callInitiated = false
            outreachBannerVisible = true
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
                    Rectangle().fill(Color.rrBorder).frame(width: 1, height: 36)
                    metaCellView(label: "Gender", value: patient?.gender?.capitalized ?? "--")
                    Rectangle().fill(Color.rrBorder).frame(width: 1, height: 36)
                    metaCellView(label: "Last PT Visit", value: formattedDOB(patient?.last_pt_visit))
                    Rectangle().fill(Color.rrBorder).frame(width: 1, height: 36)
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
                .fill(Color.rrSurface)
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
                                    .fill(Color.rrSkeleton)
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
                            .fill(Color.rrSurface)
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
                    .fill(Color.rrSurface)
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

    // MARK: - Outreach Banner

    private func outreachMessage(for status: PatientStatus, firstName: String) -> String {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let greeting = name.isEmpty ? "Hi there" : "Hi \(name)"
        switch status {
        case .fallingBehind:
            return "\(greeting)! Just checking in — we noticed you haven't done your exercises in a few days. Staying consistent is key to your recovery. Let us know if you need anything! 💪"
        case .needsHelp:
            return "\(greeting), we're reaching out because it's been a while since your last exercise session. Your recovery is important to us — please reach out or schedule a visit so we can get you back on track!"
        default:
            return ""
        }
    }

    @ViewBuilder
    private var outreachBannerView: some View {
        let accentColor = patientStatus.color
        let phone = patient?.phone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let message = outreachMessage(for: patientStatus, firstName: patient?.first_name ?? "")
        let isUrgent = patientStatus == .needsHelp
        let iconName = isUrgent ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark.fill"
        let titleText = isUrgent ? "Needs Immediate Outreach" : "Falling Behind Schedule"

        ZStack(alignment: .leading) {
            // Card background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.rrSurface)
                .shadow(color: accentColor.opacity(0.10), radius: 16, x: 0, y: 5)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accentColor.opacity(0.18), lineWidth: 1)
                )

            // Left accent stripe
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accentColor)
                    .frame(width: 4)
                    .padding(.vertical, 12)
                    .padding(.leading, 10)
                Spacer()
            }

            // Content
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accentColor.opacity(0.10))
                            .frame(width: 38, height: 38)
                        Image(systemName: iconName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(titleText)
                            .font(.rrCallout.bold())
                            .foregroundStyle(.primary)
                        Text("Suggested message ready to send")
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                // Message quote block
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor.opacity(0.45))
                        .frame(width: 3)
                    Text(message)
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(Color.primary.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.045))
                )

                // Action buttons
                Group {
                    if outreachSent {
                        HStack(spacing: 7) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PatientStatus.onTrack.color)
                            Text("Message sent to Messages app")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PatientStatus.onTrack.color)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(PatientStatus.onTrack.color.opacity(0.09))
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .center)))
                    } else if isUrgent {
                        // Needs Help: show Call + Text side by side
                        HStack(spacing: 10) {
                            // Call button
                            Button {
                                guard !phone.isEmpty else { return }
                                if let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                                    UIApplication.shared.open(url)
                                }
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                    callInitiated = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(callInitiated ? "Calling…" : "Call")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(accentColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(accentColor.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11)
                                        .strokeBorder(accentColor.opacity(0.30), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(phone.isEmpty)
                            .opacity(phone.isEmpty ? 0.45 : 1)

                            // Text button
                            Button {
                                guard !phone.isEmpty else { return }
                                let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let url = URL(string: "sms:\(phone)&body=\(encoded)") {
                                    UIApplication.shared.open(url)
                                }
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                    outreachSent = true
                                }
                                Task {
                                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                                    withAnimation(.easeOut(duration: 0.30)) {
                                        outreachBannerVisible = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Send Text")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                                .shadow(color: accentColor.opacity(0.28), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(phone.isEmpty)
                            .opacity(phone.isEmpty ? 0.45 : 1)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .center)))
                    } else {
                        // Falling Behind: single full-width text button
                        Button {
                            guard !phone.isEmpty else { return }
                            let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "sms:\(phone)&body=\(encoded)") {
                                UIApplication.shared.open(url)
                            }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                outreachSent = true
                            }
                            Task {
                                try? await Task.sleep(nanoseconds: 2_500_000_000)
                                withAnimation(.easeOut(duration: 0.30)) {
                                    outreachBannerVisible = false
                                }
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Send Text Message")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                            .shadow(color: accentColor.opacity(0.28), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(phone.isEmpty)
                        .opacity(phone.isEmpty ? 0.45 : 1)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .center)))
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: outreachSent)
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: callInitiated)
            }
            .padding(.leading, 22)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: RRSpace.section) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.rrSurface)
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
                    .fill(Color.rrSkeleton)
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
                    .fill(Color.rrSkeleton)
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
        if forceRefresh {
            await CacheService.shared.invalidate(CacheKey.patientDetail(patientProfileId: patientProfileId))
        }
        do {
            let (loadedPatient, patientStale) = try await PTService.getPatientForDisplay(patientProfileId: patientProfileId)
            self.patient = loadedPatient
            let (plan, planStale) = try await RehabService.currentPlanForDisplay(ptProfileId: ptProfileId, patientProfileId: patientProfileId)
            self.currentPlan = plan
            self.notes = plan?.notes ?? ""
            self.showOfflineBanner = !NetworkMonitor.shared.isOnline && (patientStale || planStale || forceRefresh)
            let dates = (try? await RehabService.getCompletionDates(patientProfileId: patientProfileId)) ?? []
            let computedStatus = PatientStatus.compute(from: dates)
            self.patientStatus = computedStatus
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
