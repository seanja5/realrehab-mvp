//
//  LessonAnalyticsView.swift
//  RealRehabPractice
//
//  Analytics view for a completed lesson, drawing real data from lesson_sensor_insights.
//  Same layout as AnalyticsView but fetches from Supabase.
//

import SwiftUI

struct LessonAnalyticsView: View {
    let lessonTitle: String
    let lessonId: UUID
    let patientProfileId: UUID

    @EnvironmentObject private var router: Router
    @State private var insights: LessonSensorInsightsRow?
    @State private var restSec: Int?
    @State private var isLoading = true
    @State private var loadError: String?

    /// AI-generated PT summary (nil until loaded; fallback: show skeleton)
    @State private var aiPtSummary: String? = nil
    @State private var isLoadingAISummary = false

    private var totalDuration: Double {
        guard let i = insights else { return 180 }
        return max(1, Double(i.total_duration_sec))
    }

    var body: some View {
        Group {
            if isLoading {
                SkeletonAnalyticsView(lessonTitle: lessonTitle)
            } else if let i = insights {
                contentView(insights: i)
            } else {
                emptyStateView
            }
        }
        .rrPageBackground()
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .swipeToGoBack()
        .task {
            await loadInsights()
            isLoadingAISummary = true
            await loadAISummary()
            await MainActor.run { isLoadingAISummary = false }
        }
    }

    private func contentView(insights: LessonSensorInsightsRow) -> some View {
        let driftData = mapToDriftData(insights.imu_samples)
        let shakeData = mapToShakeData(insights.shake_frequency_samples)
        let velocityData = mapToVelocityData(insights.flex_angle_samples)
        let tooFastEvents = filterEvents(insights.events, type: "too_fast")
        let tooSlowEvents = filterEvents(insights.events, type: "too_slow")
        let maxNotReachedEvents = filterEvents(insights.events, type: "max_not_reached")
        let driftEvents = filterEvents(insights.events, type: "drift_left") + filterEvents(insights.events, type: "drift_right")

        let driftCount = driftEvents.count
        let driftPercent = percentCorrect(total: insights.reps_attempted, errors: driftCount)
        let shakeCount = countShakeViolations(insights.shake_frequency_samples)
        let shakePercent = percentCorrect(total: insights.reps_attempted, errors: shakeCount)
        let tooFastPercent = percentCorrect(total: insights.reps_attempted, errors: tooFastEvents.count)
        let tooSlowPercent = percentCorrect(total: insights.reps_attempted, errors: tooSlowEvents.count)
        let maxNotReachedPercent = percentCorrect(total: insights.reps_attempted, errors: maxNotReachedEvents.count)
        let (velocityInRangePercent, peakVelocity) = computeVelocityStats(
            velocityData,
            calibrationMinDeg: insights.calibration_min_deg,
            calibrationMaxDeg: insights.calibration_max_deg,
            repMotionSec: restSec.map { Double($0) }
        )

        let repAccuracy: Double = {
            guard insights.reps_attempted > 0 else { return 100 }
            return (Double(insights.reps_completed) / Double(insights.reps_attempted)) * 100
        }()

        return ScrollView {
            VStack(alignment: .leading, spacing: RRSpace.section * 2) {
                headerView

                // Summary boxes (dynamic from insights)
                AnalyticsSummaryBoxesView(
                    repetitionAccuracyPercent: repAccuracy,
                    sessionTimeSeconds: insights.total_duration_sec,
                    attemptsCount: insights.reps_attempted,
                    assignedReps: insights.reps_target,
                    restSec: restSec
                )
                .padding(.horizontal, 16)
                .padding(.bottom, RRSpace.section)

                // AI summary: show "Summary" + skeleton while loading, then content when loaded
                VStack(alignment: .leading, spacing: RRSpace.stack) {
                    Text("Summary")
                        .font(.rrTitle)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                    if isLoadingAISummary {
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBlock(width: 280, height: 16)
                                .shimmer()
                            SkeletonBlock(width: 260, height: 16)
                                .shimmer()
                            SkeletonBlock(width: 240, height: 16)
                                .shimmer()
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.rrSurface)
                                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                        )
                        .padding(.horizontal, 16)
                    } else if let summary = aiPtSummary {
                        Text(summary)
                            .font(.rrBody)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.rrSurface)
                                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                            )
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, RRSpace.section)

                // Section 1: Leg Drift
                analyticsSection(
                    title: "Leg Drift",
                    description: "Measures lateral deviation of the knee during extension. High drift may indicate quad imbalance or poor motor control.",
                    visual: {
                        DriftGraphView(dataPoints: driftData, totalDuration: totalDuration)
                    },
                    percentLabel: "leg straightness",
                    percentValue: "\(Int(driftPercent))%",
                    countLabel: "times leg drifted too far",
                    countValue: "\(driftCount)"
                )

                // Section 2: Leg Shake / Tremor
                analyticsSection(
                    title: "Leg Shake / Tremor",
                    description: "Detects involuntary tremors during movement. Excessive shaking can indicate fatigue or neuromuscular instability.",
                    visual: {
                        ShakeGraphView(dataPoints: shakeData, totalDuration: totalDuration)
                    },
                    percentLabel: "within acceptable shake",
                    percentValue: "\(Int(shakePercent))%",
                    countLabel: "times too much shake",
                    countValue: "\(shakeCount)"
                )

                // Section 3: Angular Velocity
                analyticsSection(
                    title: "Angular Velocity",
                    description: "Tracks how fast the knee moved during active reps (°/sec). The green band is the target speed range for this lesson based on calibration and rep tempo. Spikes into red indicate reps that were too fast or too slow.",
                    visual: {
                        AngularVelocityGraphView(
                            dataPoints: velocityData,
                            totalDuration: totalDuration,
                            calibrationMinDeg: insights.calibration_min_deg,
                            calibrationMaxDeg: insights.calibration_max_deg,
                            repMotionSec: restSec.map { Double($0) }
                        )
                    },
                    percentLabel: "time in target range",
                    percentValue: "\(Int(velocityInRangePercent))%",
                    countLabel: "peak speed (°/sec)",
                    countValue: "\(Int(peakVelocity))"
                )

                // Section 4: Too Fast
                eventTimelineSection(
                    title: "Too Fast",
                    description: "Flags reps where the extension was completed too quickly. Controlled tempo is critical for proper muscle activation and tissue loading.",
                    events: tooFastEvents,
                    totalDuration: totalDuration,
                    percentLabel: "pace correct",
                    percentValue: "\(Int(tooFastPercent))%",
                    countLabel: "times too fast",
                    countValue: "\(tooFastEvents.count)"
                )

                // Section 5: Too Slow
                eventTimelineSection(
                    title: "Too Slow",
                    description: "Flags reps completed too slowly. May indicate pain avoidance, weakness, or difficulty with the prescribed tempo.",
                    events: tooSlowEvents,
                    totalDuration: totalDuration,
                    percentLabel: "pace correct",
                    percentValue: "\(Int(tooSlowPercent))%",
                    countLabel: "times too slow",
                    countValue: "\(tooSlowEvents.count)"
                )

                // Section 6: Max Not Reached
                eventTimelineSection(
                    title: "Max Not Reached",
                    description: "Tracks reps where full knee extension was not achieved. Incomplete range of motion can delay recovery milestones.",
                    events: maxNotReachedEvents,
                    totalDuration: totalDuration,
                    percentLabel: "full extension",
                    percentValue: "\(Int(maxNotReachedPercent))%",
                    countLabel: "times extend further",
                    countValue: "\(maxNotReachedEvents.count)"
                )
            }
            .padding(.bottom, 40)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(lessonTitle) Results")
                .font(.rrHeadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("No analytics data yet")
                .font(.rrTitle)
                .foregroundStyle(.secondary)
            Text("Data will appear after the patient completes this lesson with sensor collection enabled.")
                .font(.rrBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    private func analyticsSection<V: View>(
        title: String,
        description: String,
        @ViewBuilder visual: () -> V,
        percentLabel: String,
        percentValue: String,
        countLabel: String,
        countValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: RRSpace.stack) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.rrTitle)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)

            visual()
                .padding(.horizontal, 16)

            statBoxesRow(
                percentLabel: percentLabel,
                percentValue: percentValue,
                countLabel: countLabel,
                countValue: countValue
            )
            .padding(.horizontal, 16)
        }
    }

    private func eventTimelineSection(
        title: String,
        description: String,
        events: [(rep: Int, timeSec: Double)],
        totalDuration: Double,
        percentLabel: String,
        percentValue: String,
        countLabel: String,
        countValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: RRSpace.stack) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.rrTitle)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)

            EventTimelineView(events: events, totalDuration: totalDuration)
                .padding(.horizontal, 16)

            statBoxesRow(
                percentLabel: percentLabel,
                percentValue: percentValue,
                countLabel: countLabel,
                countValue: countValue
            )
            .padding(.horizontal, 16)
        }
    }

    private func statBoxesRow(
        percentLabel: String,
        percentValue: String,
        countLabel: String,
        countValue: String
    ) -> some View {
        HStack(spacing: 12) {
            statBox(main: percentValue, caption: percentLabel)
            statBox(main: countValue, caption: countLabel)
        }
    }

    private func statBox(main: String, caption: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.brandDarkBlue.opacity(0.45))
                .frame(width: 3)
                .padding(.vertical, 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(main)
                    .font(.rrHeadline)
                    .foregroundStyle(.primary)
                Text(caption)
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.rrSurface)
                .shadow(color: Color.brandDarkBlue.opacity(0.07), radius: 8, x: 0, y: 3)
                .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Data mapping

    private func mapToDriftData(_ samples: [IMUSample]) -> [(time: Double, imu: Double)] {
        samples.map { (time: Double($0.timeMs) / 1000, imu: $0.imuValue) }
    }

    private func mapToShakeData(_ samples: [ShakeSample]) -> [(time: Double, frequency: Double)] {
        samples.map { (time: Double($0.timeMs) / 1000, frequency: $0.frequency) }
    }

    private func mapToVelocityData(_ samples: [FlexAngleSample]) -> [(time: Double, angleDeg: Double)] {
        samples.map { (time: Double($0.timeMs) / 1000, angleDeg: $0.angleDeg) }
    }

    /// Returns (percentInRange, peakVelocity) using the same gap-skip logic as AngularVelocityGraphView.
    private func computeVelocityStats(
        _ dataPoints: [(time: Double, angleDeg: Double)],
        calibrationMinDeg: Double?,
        calibrationMaxDeg: Double?,
        repMotionSec: Double?
    ) -> (pctInRange: Double, peak: Double) {
        guard dataPoints.count >= 2 else { return (100, 0) }
        let angularRange: Double = {
            guard let mn = calibrationMinDeg, let mx = calibrationMaxDeg, mx > mn else { return 40 }
            return mx - mn
        }()
        let oneStrokeSec = max(0.5, (repMotionSec ?? 3.0) / 2.0)
        let targetVelocity = angularRange / oneStrokeSec
        let minGood = targetVelocity * 0.5
        let maxGood = targetVelocity * 1.5

        var inRange = 0
        var total = 0
        var peak: Double = 0
        for i in 1..<dataPoints.count {
            let p1 = dataPoints[i - 1]
            let p2 = dataPoints[i]
            let dt = p2.time - p1.time
            guard dt > 0 && dt <= 0.3 else { continue }
            let speed = abs(p2.angleDeg - p1.angleDeg) / dt
            total += 1
            if speed >= minGood && speed <= maxGood { inRange += 1 }
            if speed > peak { peak = speed }
        }
        let pct = total > 0 ? Double(inRange) / Double(total) * 100 : 100
        return (pct, peak)
    }

    private func filterEvents(_ events: [LessonSensorEventRecord], type: String) -> [(rep: Int, timeSec: Double)] {
        events
            .filter { $0.eventType == type }
            .map { (rep: $0.repAttempt, timeSec: $0.timeSec) }
    }

    private func percentCorrect(total: Int, errors: Int) -> Double {
        guard total > 0 else { return 100 }
        let correct = max(0, total - errors)
        return (Double(correct) / Double(total)) * 100
    }

    private func countShakeViolations(_ samples: [ShakeSample]) -> Int {
        let threshold: Double = 0.85
        var violations = 0
        var inViolation = false
        for s in samples {
            if s.frequency > threshold {
                if !inViolation {
                    violations += 1
                    inViolation = true
                }
            } else {
                inViolation = false
            }
        }
        return violations
    }

    private func loadInsights() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let fetched = try await LessonSensorInsightsService.fetch(lessonId: lessonId, patientProfileId: patientProfileId)
            await MainActor.run { insights = fetched }
            if let i = fetched, let plan = try? await RehabService.currentPlan(ptProfileId: i.pt_profile_id, patientProfileId: patientProfileId),
               let node = plan.nodes?.first(where: { UUID(uuidString: $0.id) == lessonId }) {
                await MainActor.run { restSec = node.restSec }
            } else {
                await MainActor.run { restSec = nil }
            }
        } catch {
            loadError = error.localizedDescription
            insights = nil
            restSec = nil
        }
    }

    private func loadAISummary() async {
        guard let insights = insights else { return }
        if let summary = await LessonSummaryService.fetchPTSummary(
            lessonId: lessonId,
            patientProfileId: patientProfileId,
            insights: insights
        ) {
            await MainActor.run { aiPtSummary = summary }
        }
    }
}

// MARK: - Skeleton loading view

private struct SkeletonAnalyticsView: View {
    let lessonTitle: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpace.section * 2) {
                Text("\(lessonTitle) Results")
                    .font(.rrHeadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                ForEach(0..<5, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 24)
                            .frame(maxWidth: 200)
                        SkeletonBlock(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        SkeletonBlock(height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 40)
        }
    }
}
