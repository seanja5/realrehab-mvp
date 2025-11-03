import SwiftUI

struct HomeView: View {
    @EnvironmentObject var router: Router
    @State private var searchText = ""
    
    private let lower: [(String, String)] = [
        ("Knee", "knee_placeholder"),
        ("Hip", "hip_placeholder"),
        ("Ankle", "ankle_placeholder")
    ]
    
    private let upper: [(String, String)] = [
        ("Shoulder", "shoulder_placeholder"),
        ("Elbow", "elbow_placeholder"),
        ("Wrist", "wrist_placeholder")
    ]
    
    private let spine: [(String, String)] = [
        ("Cervical", "cervical_placeholder"),
        ("Thoracic", "thoracic_placeholder"),
        ("Lumbar", "lumbar_placeholder")
    ]
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                // Search
                SearchBar(text: $searchText)
                    .padding(.top, RRSpace.pageTop)
                    .padding(.horizontal, 16)
                
                // Lower Extremity
                section(title: "Lower Extremity", items: lower)
                
                // Upper Extremity
                section(title: "Upper Extremity", items: upper)
                
                // Spine & Core
                section(title: "Spine & Core", items: spine)
            }
            .padding(.bottom, 24)
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
                            action: {
                                if name == "Knee" {
                                    router.go(.homeSubCategory)
                                } else {
                                    print("Selected \(name) — TODO route later")
                                }
                            }
                        )
                        .frame(width: 110)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
