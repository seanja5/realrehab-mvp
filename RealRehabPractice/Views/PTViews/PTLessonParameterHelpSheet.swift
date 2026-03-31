import SwiftUI

/// Glossary of lesson parameters for PTs editing rehab plans.
struct PTLessonParameterHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RRSpace.section) {
                    paramRow(
                        title: "Number of repetitions",
                        detail: "How many times the patient completes the movement (or hold) in one set before resting between sets."
                    )
                    paramRow(
                        title: "Repetition temp",
                        detail: "Total seconds for one lift and one lower, split evenly (half up, half down). This sets how fast each rep should move — not idle time between reps, and not rest between sets."
                    )
                    paramRow(
                        title: "Number of sets",
                        detail: "How many rounds of repetitions to complete, with optional rest between each round."
                    )
                    paramRow(
                        title: "Rest in between sets",
                        detail: "How long the patient pauses after finishing all reps in a set before starting the next set."
                    )
                    paramRow(
                        title: "Knee bend angle",
                        detail: "For exercises like wall sits: target knee angle in degrees for the hold position."
                    )
                    paramRow(
                        title: "Time holding position",
                        detail: "How long the patient holds a fixed position. Meaning depends on the exercise — for example wall sit duration, benchmark extension hold, or Quad Sets: how long to hold the thigh contraction at the top before lowering."
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("Parameter help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.rrBody)
                }
            }
        }
    }

    private func paramRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.rrHeadline)
            Text(detail)
                .font(.rrBody)
                .foregroundStyle(.secondary)
        }
    }
}
