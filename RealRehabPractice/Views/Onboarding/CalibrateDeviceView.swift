import SwiftUI

struct CalibrateDeviceView: View {
    @EnvironmentObject var router: Router
    @State private var startSet = false
    @State private var maxSet = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    StepIndicator(current: 3, total: 3, showLabel: true)
                        .padding(.top, 8)
                    
                    VStack(spacing: RRSpace.section) {
                        Text("Calibrate Device")
                            .font(.rrHeadline)
                        Text("Set your movement range so tracking is accurate.")
                            .font(.rrCallout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Divider()
                            .padding(.vertical, 4)
                        VStack(alignment: .leading, spacing: RRSpace.stack) {
                            SecondaryButton(title: startSet ? "Starting Position ✓" : "Set Starting Position") {
                                startSet = true
                            }
                            SecondaryButton(title: maxSet ? "Maximum Position ✓" : "Set Maximum Position") {
                                maxSet = true
                            }
                        }
                        Spacer()
                            .frame(minHeight: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            
            // Bottom button
            VStack {
                PrimaryButton(
                    title: "Finish Calibration!",
                    isDisabled: !(startSet && maxSet),
                    useLargeFont: true,
                    action: {
                        router.go(.allSet)
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .safeAreaPadding(.bottom)
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}