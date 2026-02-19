//
//  AnalyticsSummaryBoxesView.swift
//  RealRehabPractice
//
//  Summary section for analytics: Repetition Accuracy (with pie chart), Session Time, Attempts.
//

import SwiftUI

struct AnalyticsSummaryBoxesView: View {
    let repetitionAccuracyPercent: Double
    let sessionTimeSeconds: Int
    let attemptsCount: Int
    let assignedReps: Int
    /// Rest time in seconds between sets (assigned). When nil, rest box shows "—".
    let restSec: Int?

    private var sessionTimeFormatted: String {
        let m = sessionTimeSeconds / 60
        let s = sessionTimeSeconds % 60
        return "\(m):\(s < 10 ? "0" : "")\(s)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpace.stack) {
            repetitionAccuracyBox
            HStack(spacing: RRSpace.stack) {
                sessionTimeBox
                restBox
            }
        }
    }

    private var repetitionAccuracyBox: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(repetitionAccuracyPercent))% repetition accuracy")
                    .font(.rrHeadline)
                    .foregroundStyle(.primary)
                Text("(\(attemptsCount) attempts / \(assignedReps) assigned)")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            pieChart(progress: min(1, max(0, repetitionAccuracyPercent / 100)))
                .offset(x: -40)
                .padding(.trailing, 10)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(boxBackground)
    }

    private var sessionTimeBox: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sessionTimeFormatted)
                .font(.rrHeadline)
                .foregroundStyle(.primary)
            Text("session time")
                .font(.rrCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(boxBackground)
    }

    private var restBox: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(restSec.map { "\($0) secs" } ?? "—")
                .font(.rrHeadline)
                .foregroundStyle(.primary)
            Text("rest in between sets")
                .font(.rrCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(boxBackground)
    }

    private var boxBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func pieChart(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.brandDarkBlue, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 56, height: 56)
    }
}
