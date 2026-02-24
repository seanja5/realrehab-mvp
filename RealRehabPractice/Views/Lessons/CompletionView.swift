import SwiftUI

struct CompletionView: View {
    let lessonId: UUID?
    @EnvironmentObject var router: Router
    @State private var rangeGained: Int? = nil
    @State private var isLoadingRange: Bool = true
    @State private var insights: LessonSensorInsightsRow? = nil
    @State private var isLoadingInsights: Bool = true
    @State private var showScoreExplanation: Bool = false
    @State private var patientProfileId: UUID?
    @State private var lessonTitleForAnalytics: String = "Lesson"
    // Animated score: number shows immediately; circle driven by TimelineView (time-based, one update per frame).
    @State private var displayedScore: Int = 0
    @State private var animationStartTime: Date? = nil
    @State private var targetProgress: Double = 0
    @State private var hasAnimatedScore: Bool = false

    /// AI-generated summary (nil = use PatientLessonScore fallback after load completes)
    @State private var aiPatientSummary: String? = nil
    @State private var aiNextTimeCue: String? = nil
    /// True while fetching AI summary; sheet shows skeleton until this is false.
    @State private var isLoadingAISummary: Bool = false

    private let circleAnimationDuration: Double = 1.2

    /// True until both insights and range have finished loading — use for full-screen skeleton.
    private var isScreenLoading: Bool {
        isLoadingInsights || isLoadingRange
    }

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

    private var repetitionAccuracyValue: String {
        guard let i = insights else { return "—" }
        let pct = i.reps_attempted > 0 ? Int((Double(i.reps_completed) / Double(i.reps_attempted)) * 100) : 0
        return "\(pct)% repetition accuracy"
    }

    private var repetitionAccuracySubtitle: String {
        guard let i = insights else { return "—" }
        return "\(i.reps_attempted) attempts out of \(i.reps_target) assigned reps"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    if isScreenLoading {
                        SkeletonBlock(width: 140, height: 24)
                        SkeletonBlock(width: 100, height: 22)
                            .padding(.top, 2)
                    } else {
                        Text("You Did It!")
                            .font(.rrHeadline)
                        Text("Your Score:")
                            .font(.rrHeadline)
                    }
                }
                .padding(.top, RRSpace.pageTop)
                .frame(minHeight: 56)

                // Score card: large circular ring + percentage + info icon
                scoreCardView
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                // Metric cards: Session and Range side-by-side, then Rep accuracy full width
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        metricCard(icon: "clock", title: "Session", value: sessionTimeFormatted, isLoading: isScreenLoading)
                        metricCard(icon: "chart.pie", title: "Range gained", value: rangeText, isLoading: isScreenLoading)
                    }
                    metricCard(icon: "scope", title: repetitionAccuracySubtitle, value: repetitionAccuracyValue, isLoading: isScreenLoading)
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .padding(.bottom, RRSpace.section)

                // Summary (same style as PT analytics) — AI summary or fallback
                summarySection
                    .padding(.horizontal, 16)
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
            .padding(.top, 20)
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
            guard let lid = lessonId else { return }
            // Restore from cache so we don't show skeleton when returning to this screen
            if let cached = await CompletionPageCache.shared.get(lid), cached.insights != nil {
                await MainActor.run {
                    insights = cached.insights
                    isLoadingInsights = false
                    rangeGained = cached.rangeGained
                    isLoadingRange = false
                    aiPatientSummary = cached.aiPatientSummary
                    aiNextTimeCue = cached.aiNextTimeCue
                    isLoadingAISummary = false
                    if let pid = cached.patientProfileId { patientProfileId = pid }
                    lessonTitleForAnalytics = cached.lessonTitleForAnalytics
                    if !hasAnimatedScore, let i = cached.insights {
                        let result = PatientLessonScore.compute(insights: i)
                        hasAnimatedScore = true
                        displayedScore = min(100, max(0, result.score))
                        targetProgress = Double(displayedScore) / 100
                        animationStartTime = Date()
                    }
                }
                return
            }
            isLoadingAISummary = true
            await loadInsights()
            await loadAISummary()
            await loadRangeGained()
            await notifyPTIfNeeded()
            // Cache so next time we open this completion screen it shows instantly
            await cacheCompletionPage(lessonId: lid)
        }
        .onChange(of: computedScore?.score) { _, newValue in
            guard let targetScore = newValue, !hasAnimatedScore else { return }
            hasAnimatedScore = true
            let target = min(100, max(0, targetScore))
            displayedScore = target
            targetProgress = Double(target) / 100
            animationStartTime = Date()
        }
    }

    private var scoreCardView: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .center) {
                if isScreenLoading {
                    // Loading: empty circle (no skeleton/shimmer) + placeholder text
                    circularProgressRing(progress: 0)
                        .frame(width: 168, height: 168)
                    Text("—")
                        .font(.system(size: 43, weight: .bold))
                        .foregroundStyle(.secondary)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0/60.0)) { context in
                        let progress = progressForCircle(at: context.date)
                        circularProgressRing(progress: progress)
                    }
                    .frame(width: 168, height: 168)
                    Text("\(displayedScore)%")
                        .font(.system(size: 43, weight: .bold))
                        .foregroundStyle(.primary)
                }
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
                .opacity(isScreenLoading ? 0 : 1)
            }
        }
    }

    /// Progress 0...1 for the circle at the given time (ease-out over circleAnimationDuration).
    private func progressForCircle(at now: Date) -> Double {
        guard let start = animationStartTime else { return 0 }
        let elapsed = now.timeIntervalSince(start)
        let t = min(1, elapsed / circleAnimationDuration)
        let easeOut = 1 - (1 - t) * (1 - t)
        return min(1, max(0, easeOut * targetProgress))
    }

    private func circularProgressRing(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 18)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(Color.brandDarkBlue, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                .rotationEffect(.degrees(-90))
        }
    }

    private func metricCard(icon: String, title: String, value: String, isLoading: Bool = false) -> some View {
        HStack(spacing: 12) {
            if isLoading {
                // Skeleton layout matching real card: icon + value line + title line
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.88))
                    .frame(width: 24, height: 24)
                    .shimmer()
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonBlock(width: 80, height: 20)
                    SkeletonBlock(width: 120, height: 14)
                }
                Spacer(minLength: 0)
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

    /// Summary block below metric cards (same style as PT analytics). Shows AI summary or fallback.
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: RRSpace.stack) {
            Text("Summary")
                .font(.rrTitle)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)

            if isLoadingAISummary {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(width: 280, height: 16)
                        .shimmer()
                    SkeletonBlock(width: 260, height: 16)
                        .shimmer()
                    SkeletonBlock(width: 240, height: 16)
                        .shimmer()
                    SkeletonBlock(width: 220, height: 16)
                        .shimmer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                )
            } else if let summary = aiPatientSummary, !summary.isEmpty {
                Text(summary)
                    .font(.rrBody)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    )
            } else if let fallback = computedScore.map({ PatientLessonScore.whatItMeans(for: $0.score) }) {
                Text(fallback)
                    .font(.rrBody)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    )
            }
        }
    }

    private var scoreExplanationSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RRSpace.section * 2) {
                    Text("How we calculated it")
                        .font(.rrTitle)
                        .foregroundStyle(.primary)
                    Text(insights.map { PatientLessonScore.howCalculated(insights: $0) } ?? "")
                        .font(.rrBody)
                        .foregroundStyle(.primary)

                    if let pid = patientProfileId, let lid = lessonId {
                        Button {
                            showScoreExplanation = false
                            router.go(.ptLessonAnalytics(lessonTitle: lessonTitleForAnalytics, lessonId: lid, patientProfileId: pid))
                        } label: {
                            Text("Advanced Analytics")
                                .font(.rrBody)
                                .underline()
                                .foregroundStyle(Color.brandLightBlue)
                        }
                        .padding(.top, 16)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Your Score")
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
            await MainActor.run {
                insights = fetched
                patientProfileId = profile.id
            }
        } catch {
            await MainActor.run { insights = nil }
        }
    }

    private func loadRangeGained() async {
        isLoadingRange = true
        // Use this lesson's completed_at so range gained is specific to this lesson (calibrations as of then).
        let completedBefore = await MainActor.run { insights?.completed_at }
        do {
            let points = try await TelemetryService.getAllMaximumCalibrationsForPatient(before: completedBefore)
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
            await MainActor.run {
                self.patientProfileId = patientProfileId
                self.lessonTitleForAnalytics = lessonTitle
            }
        } catch { }
    }

    private func loadAISummary() async {
        guard let lessonId = lessonId,
              let patientProfileId = patientProfileId,
              let insights = insights else {
            await MainActor.run { isLoadingAISummary = false }
            return
        }
        await MainActor.run { isLoadingAISummary = true }
        if let result = await LessonSummaryService.fetchPatientSummary(
            lessonId: lessonId,
            patientProfileId: patientProfileId,
            insights: insights
        ) {
            await MainActor.run {
                aiPatientSummary = result.patientSummary
                aiNextTimeCue = result.nextTimeCue
            }
        }
        await MainActor.run { isLoadingAISummary = false }
    }

    private func cacheCompletionPage(lessonId: UUID) async {
        let entry = await MainActor.run {
            CompletionPageCache.Entry(
                insights: insights,
                rangeGained: rangeGained,
                aiPatientSummary: aiPatientSummary,
                aiNextTimeCue: aiNextTimeCue,
                patientProfileId: patientProfileId,
                lessonTitleForAnalytics: lessonTitleForAnalytics
            )
        }
        await CompletionPageCache.shared.set(lessonId, entry)
    }
}

// MARK: - Completion page cache (in-memory so returning to the screen shows data instantly)
private actor CompletionPageCache {
    struct Entry {
        var insights: LessonSensorInsightsRow?
        var rangeGained: Int?
        var aiPatientSummary: String?
        var aiNextTimeCue: String?
        var patientProfileId: UUID?
        var lessonTitleForAnalytics: String
    }
    static let shared = CompletionPageCache()
    private var storage: [UUID: Entry] = [:]
    func get(_ lessonId: UUID) -> Entry? { storage[lessonId] }
    func set(_ lessonId: UUID, _ entry: Entry) { storage[lessonId] = entry }
}
