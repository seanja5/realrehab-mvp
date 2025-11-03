import SwiftUI

struct HomeSubCategoryView: View {
    @EnvironmentObject var router: Router
    @State private var search = ""
    var body: some View {
        VStack {
            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding()
            List {
                Section("Ligaments") {
                    Text("ACL").font(.rrBody)
                    Text("Meniscus").font(.rrBody)
                    Text("PCL").font(.rrBody)
                }
                Section("Tendons") {
                    Text("Jumper's Knee").font(.rrBody)
                    Text("IT Band").font(.rrBody)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") { router.go(.rehabOverview) }
                    .font(.rrBody)
            }
        }
        .rrPageBackground()
    }
}