import SwiftUI

struct CompletionView: View {
    let lessonId: UUID?
    @EnvironmentObject var router: Router
    @State private var rangeGained: Int? = nil
    @State private var isLoadingRange: Bool = true
    
    init(lessonId: UUID? = nil) {
        self.lessonId = lessonId
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Title group
                Text("You Did It!")
                    .font(.rrHeadline)
                    .padding(.top, RRSpace.pageTop)
                
                // Spacer to push metrics down
                Spacer(minLength: 100)
                
                // Metrics stack - centered, one per row
                VStack(spacing: 16) {
                    // Session card
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.rrBody)
                            .foregroundStyle(.primary)
                        Text("Session: 3 min")
                            .font(.rrTitle)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    
                    // Range card
                    HStack(spacing: 12) {
                        Image(systemName: "chart.pie")
                            .font(.rrBody)
                            .foregroundStyle(.primary)
                        Text(rangeText)
                            .font(.rrTitle)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    
                    // Accuracy card
                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .font(.rrBody)
                            .foregroundStyle(.primary)
                        Text("Accuracy: 93%")
                            .font(.rrTitle)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                    )
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                
                // Progress graph section (same as dashboard)
                RecoveryChartWeekView()
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Bottom buttons
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
            await loadRangeGained()
            await notifyPTIfNeeded()
        }
    }
    
    private var rangeText: String {
        if isLoadingRange {
            return "Range: Loading..."
        } else if let range = rangeGained {
            return "Range: +\(range)°"
        } else {
            return "Range: --"
        }
    }
    
    private func loadRangeGained() async {
        isLoadingRange = true
        do {
            let points = try await TelemetryService.getAllMaximumCalibrationsForPatient()
            
            // Get the two most recent maximum calibration values
            // Points are sorted chronologically, so last two are most recent
            guard points.count >= 2 else {
                await MainActor.run {
                    rangeGained = nil
                    isLoadingRange = false
                }
                return
            }
            
            let mostRecent = points[points.count - 1].degrees
            let secondMostRecent = points[points.count - 2].degrees
            
            let difference = mostRecent - secondMostRecent
            
            await MainActor.run {
                rangeGained = difference
                isLoadingRange = false
                print("✅ CompletionView: Range gained calculated - Most recent: \(mostRecent)°, Second most recent: \(secondMostRecent)°, Difference: \(difference)°")
            }
        } catch {
            await MainActor.run {
                rangeGained = nil
                isLoadingRange = false
                print("❌ CompletionView: Failed to load range gained: \(error)")
            }
        }
    }
    
    /// Notify the PT that this patient completed the lesson (if PT has the setting enabled). Called once when view appears.
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
            print("✅ CompletionView: Notified PT of session complete for lesson \(lessonId)")
        } catch {
            print("⚠️ CompletionView: Failed to notify PT: \(error)")
        }
    }
}
