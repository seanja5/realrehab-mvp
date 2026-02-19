import SwiftUI

struct CompletionView: View {
    let lessonId: UUID?
    @EnvironmentObject var router: Router
    @State private var rangeGained: Int? = nil
    @State private var isLoadingRange: Bool = true
    @State private var insights: LessonSensorInsightsRow? = nil
    @State private var isLoadingInsights: Bool = true
    @State private var showScoreExplanation: Bool = false

    init(lessonId: UUID? = nil) {
        self.lessonId = lessonId
    }

    private var computedScore: (score: Int, explanation: String)? {
        guard let i = insights else { return nil }
        let result = PatientLessonScore.compute(insights: i)
        return (result.score, result.explanation)
    }

    private var sessionTimeFormatted: String {
        guard let i = insights else { return "—" }
        let m = i.total_duration_sec / 60
        let s = i.total_duration_sec % 60
        return "\(m):\(s < 10 ? "0" : "")\(s)"
    }

    private var repetitionAccuracyText: String {
        guard let i = insights else { return "—" }
        let pct = i.reps_target > 0 ? Int((Double(i.reps_completed) / Double(i.reps_target)) * 100) : 0
        return "\(i.reps_completed) / \(i.reps_target) reps (\(pct)%)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("You Did It!")
                    .font(.rrHeadline)
                    .padding(.top, RRSpace.pageTop)

                // Score card: large circular ring + percentage + info icon
                scoreCardView
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                // Metric cards
                VStack(spacing: 16) {
                    metricCard(icon: "clock", title: "Session", value: isLoadingInsights ? "Loading..." : sessionTimeFormatted)
                    metricCard(icon: "chart.pie", title: "Range gained", value: rangeText, isLoading: isLoadingRange)
                    metricCard(icon: "chart.bar.fill", title: "Repetition accuracy", value: isLoadingInsights ? "Loading..." : repetitionAccuracyText)
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)

                RecoveryChartWeekView()
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                PrimaryButton(title: "Back to Journey Map") {
                    router.go(.journeyMap)
                }
                SecondaryButton(title: "Return to Dashboard") {
                    router.go(.ptDetail)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showScoreExplanation) {
            scoreExplanationSheet
        }
        .rrPageBackground()
        .navigationTitle("Complete")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .swipeToGoBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .task {
            await loadInsights()
            await loadRangeGained()
            await notifyPTIfNeeded()
        }
    }

    private var scoreCardView: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .center) {
                circularProgressRing(progress: computedScore.map { min(1, max(0, Double($0.score) / 100)) } ?? 0)
                    .frame(width: 140, height: 140)
                Text(computedScore != nil ? "\(computedScore!.score)%" : "—")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    showScoreExplanation = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                .offset(x: 8, y: -8)
            }
        }
    }

    private func circularProgressRing(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 18)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(Color.brandDarkBlue, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    private func metricCard(icon: String, title: String, value: String, isLoading: Bool = false) -> some View {
        HStack(spacing: 12) {
            if isLoading {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.88))
                    .frame(width: 24, height: 24)
                    .shimmer()
                SkeletonBlock(width: 120, height: 20)
            } else {
                Image(systemName: icon)
                    .font(.rrBody)
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.rrTitle)
                        .foregroundStyle(.primary)
                    Text(title)
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var scoreExplanationSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RRSpace.section) {
                    Text(computedScore.map { PatientLessonScore.scoreExplanation(for: $0.score) } ?? "")
                        .font(.rrBody)
                        .foregroundStyle(.primary)
                }
                .padding(24)
            }
            .navigationTitle("What this score means")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showScoreExplanation = false }
                }
            }
        }
    }

    private var rangeText: String {
        if isLoadingRange {
            return "Loading..."
        } else if let range = rangeGained {
            return "+\(range)°"
        } else {
            return "—"
        }
    }

    private func loadInsights() async {
        guard let lessonId = lessonId else {
            isLoadingInsights = false
            return
        }
        isLoadingInsights = true
        defer { isLoadingInsights = false }
        do {
            let profile = try await PatientService.myPatientProfile()
            let fetched = try await LessonSensorInsightsService.fetch(lessonId: lessonId, patientProfileId: profile.id)
            await MainActor.run { insights = fetched }
        } catch {
            await MainActor.run { insights = nil }
        }
    }

    private func loadRangeGained() async {
        isLoadingRange = true
        do {
            let points = try await TelemetryService.getAllMaximumCalibrationsForPatient()
            guard points.count >= 2 else {
                await MainActor.run { rangeGained = nil; isLoadingRange = false }
                return
            }
            let mostRecent = points[points.count - 1].degrees
            let secondMostRecent = points[points.count - 2].degrees
            await MainActor.run {
                rangeGained = mostRecent - secondMostRecent
                isLoadingRange = false
            }
        } catch {
            await MainActor.run { rangeGained = nil; isLoadingRange = false }
        }
    }

    private func notifyPTIfNeeded() async {
        guard let lessonId = lessonId else { return }
        do {
            let patientProfile = try await PatientService.myPatientProfile()
            let patientProfileId = patientProfile.id
            guard let ptProfileId = try await PatientService.getPTProfileId(patientProfileId: patientProfileId) else { return }
            let lessonTitle: String
            if let plan = try await RehabService.currentPlan(ptProfileId: ptProfileId, patientProfileId: patientProfileId),
               let node = plan.nodes?.first(where: { UUID(uuidString: $0.id) == lessonId }) {
                lessonTitle = node.title.isEmpty ? "Lesson" : node.title
            } else {
                lessonTitle = "Lesson"
            }
            try await PatientService.notifyPTSessionComplete(patientProfileId: patientProfileId, lessonId: lessonId, lessonTitle: lessonTitle)
        } catch { }
    }
}
