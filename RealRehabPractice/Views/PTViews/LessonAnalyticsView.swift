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
    @State private var isLoading = true
    @State private var loadError: String?

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
        .task { await loadInsights() }
    }

    private func contentView(insights: LessonSensorInsightsRow) -> some View {
        let driftData = mapToDriftData(insights.imu_samples)
        let shakeData = mapToShakeData(insights.shake_frequency_samples)
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
                    assignedReps: insights.reps_target
                )
                .padding(.horizontal, 16)
                .padding(.bottom, RRSpace.section)

                // Section 1: Dynamic Valgus
                analyticsSection(
                    title: "Dynamic Valgus (Leg Drift Graph)",
                    visual: {
                        DriftGraphView(dataPoints: driftData, totalDuration: totalDuration)
                    },
                    percentLabel: "leg straightness",
                    percentValue: "\(Int(driftPercent))%",
                    countLabel: "times leg drifted too far",
                    countValue: "\(driftCount)"
                )

                // Section 2: Leg Shakes
                analyticsSection(
                    title: "Leg Shakes / Wobbles Graph",
                    visual: {
                        ShakeGraphView(dataPoints: shakeData, totalDuration: totalDuration)
                    },
                    percentLabel: "within acceptable shake",
                    percentValue: "\(Int(shakePercent))%",
                    countLabel: "times too much shake",
                    countValue: "\(shakeCount)"
                )

                // Section 3: Too fast
                eventTimelineSection(
                    title: "Too Fast",
                    events: tooFastEvents,
                    totalDuration: totalDuration,
                    percentLabel: "pace correct",
                    percentValue: "\(Int(tooFastPercent))%",
                    countLabel: "times too fast",
                    countValue: "\(tooFastEvents.count)"
                )

                // Section 4: Too slow
                eventTimelineSection(
                    title: "Too Slow",
                    events: tooSlowEvents,
                    totalDuration: totalDuration,
                    percentLabel: "pace correct",
                    percentValue: "\(Int(tooSlowPercent))%",
                    countLabel: "times too slow",
                    countValue: "\(tooSlowEvents.count)"
                )

                // Section 5: Max not reached
                eventTimelineSection(
                    title: "Max Not Reached",
                    events: maxNotReachedEvents,
                    totalDuration: totalDuration,
                    percentLabel: "full extension",
                    percentValue: "\(Int(maxNotReachedPercent))%",
                    countLabel: "times extend further",
                    countValue: "\(maxNotReachedEvents.count)"
                )

                // Section 6: Anterior knee migration (hardcoded - no hardware)
                eventTimelineSection(
                    title: "Anterior Knee Migration (Knee Over Toe)",
                    events: [],
                    totalDuration: totalDuration,
                    percentLabel: "knee behind toe",
                    percentValue: "100%",
                    countLabel: "times knee over toe",
                    countValue: "0"
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
        @ViewBuilder visual: () -> V,
        percentLabel: String,
        percentValue: String,
        countLabel: String,
        countValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: RRSpace.stack) {
            Text(title)
                .font(.rrTitle)
                .foregroundStyle(.primary)
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
        events: [(rep: Int, timeSec: Double)],
        totalDuration: Double,
        percentLabel: String,
        percentValue: String,
        countLabel: String,
        countValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: RRSpace.stack) {
            Text(title)
                .font(.rrTitle)
                .foregroundStyle(.primary)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(main)
                .font(.rrHeadline)
                .foregroundStyle(.primary)
            Text(caption)
                .font(.rrCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Data mapping

    private func mapToDriftData(_ samples: [IMUSample]) -> [(time: Double, imu: Double)] {
        samples.map { (time: Double($0.timeMs) / 1000, imu: $0.imuValue) }
    }

    private func mapToShakeData(_ samples: [ShakeSample]) -> [(time: Double, frequency: Double)] {
        samples.map { (time: Double($0.timeMs) / 1000, frequency: $0.frequency) }
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
            insights = try await LessonSensorInsightsService.fetch(lessonId: lessonId, patientProfileId: patientProfileId)
        } catch {
            loadError = error.localizedDescription
            insights = nil
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

                ForEach(0..<6, id: \.self) { _ in
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
