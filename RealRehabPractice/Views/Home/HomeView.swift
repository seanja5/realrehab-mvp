import SwiftUI

struct HomeView: View {
    @EnvironmentObject var router: Router
    var body: some View {
        List {
            Section("Discover") {
                Button("Browse Conditions") { router.go(.homeSubCategory) }
                    .font(.rrBody)
            }
            Section("Your Journey") {
                Button("Open Rehab Overview") { router.go(.rehabOverview) }
                    .font(.rrBody)
                Button("Open Journey Map") { router.go(.journeyMap) }
                    .font(.rrBody)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .rrPageBackground()
    }
}