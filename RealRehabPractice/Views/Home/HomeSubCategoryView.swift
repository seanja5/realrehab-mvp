import SwiftUI

struct HomeSubCategoryView: View {
    @EnvironmentObject var router: Router
    @State private var searchText = ""
    
    private let ligaments: [(String, String)] = [
        ("ACL", "acl_placeholder"),
        ("Meniscus", "meniscus_placeholder"),
        ("PCL", "pcl_placeholder")
    ]
    
    private let tendons: [(String, String)] = [
        ("Jumper's Knee", "jumpers_placeholder"),
        ("IT Band", "itband_placeholder")
    ]
    
    private let kneeReplacement: [(String, String)] = [
        ("Mobility", "mobility_placeholder"),
        ("Swelling Reduction", "swelling_placeholder"),
        ("Range of Motion", "rom_placeholder")
    ]
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                // Search
                SearchBar(text: $searchText, placeholder: "Search Knee")
                    .padding(.top, RRSpace.pageTop)
                    .padding(.horizontal, 16)
                
                // Ligaments
                section(title: "Ligaments", items: ligaments)
                
                // Tendons
                section(title: "Tendons", items: tendons)
                
                // Knee Replacement Recovery
                section(title: "Knee Replacement Recovery", items: kneeReplacement)
            }
            .padding(.bottom, 24)
        }
        .rrPageBackground()
        .navigationTitle("Injuries")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
    
    @ViewBuilder
    private func section(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.rrTitle)
                .bold()
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(items, id: \.0) { (name, imageName) in
                        BodyPartCard(
                            title: name,
                            imageName: imageName,
                            tappable: name == "ACL",
                            action: name == "ACL" ? {
                                router.go(.rehabOverview)
                            } : nil
                        )
                        .frame(width: 110)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

