import SwiftUI

struct HomeView: View {
    @EnvironmentObject var router: Router
    var body: some View {
        List {
            Section("Discover") {
                Button("Browse Conditions") { router.go(.homeSubCategory) }
            }
            Section("Your Journey") {
                Button("Open Rehab Overview") { router.go(.rehabOverview) }
                Button("Open Journey Map") { router.go(.journeyMap) }
            }
        }
        .navigationTitle("Home")
    }
}