import SwiftUI

struct HomeSubCategoryView: View {
    @EnvironmentObject var router: Router
    @State private var search = ""
    var body: some View {
        VStack {
            TextField("Search", text: $search).textFieldStyle(.roundedBorder).padding()
            List {
                Section("Ligaments") { Text("ACL"); Text("Meniscus"); Text("PCL") }
                Section("Tendons") { Text("Jumper’s Knee"); Text("IT Band") }
            }
        }
        .navigationTitle("Discover")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Next") { router.go(.rehabOverview) } } }
    }
}