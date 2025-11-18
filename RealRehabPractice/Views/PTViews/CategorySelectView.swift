import SwiftUI

struct CategorySelectView: View {
    let patientProfileId: UUID
    @EnvironmentObject var router: Router
    
    private let lower: [(String, String)] = [
        ("Knee", "knee"),
        ("Hip", "hip"),
        ("Ankle", "ankle")
    ]
    
    private let upper: [(String, String)] = [
        ("Shoulder", "shoulder"),
        ("Elbow", "elbow"),
        ("Wrist", "wrist")
    ]
    
    private let spine: [(String, String)] = [
        ("Cervical", "cervical"),
        ("Thoracic", "thoracic"),
        ("Lumbar", "lumbar")
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    section(title: "Lower Extremity", items: lower)
                    section(title: "Upper Extremity", items: upper)
                    section(title: "Spine & Core", items: spine)
                }
                .padding(.top, RRSpace.pageTop)
                .padding(.bottom, 120)
            }
            
            PTTabBar(selected: .dashboard) { tab in
                switch tab {
                case .dashboard:
                    router.goWithoutAnimation(.patientList)
                case .settings:
                    router.goWithoutAnimation(.ptSettings)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .rrPageBackground()
        .navigationTitle("Select Category")
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
                            tappable: name == "Knee",
                            action: name == "Knee" ? {
                                router.go(.ptInjurySelect(patientProfileId: patientProfileId))
                            } : nil
                        )
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

