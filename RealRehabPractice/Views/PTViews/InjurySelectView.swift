import SwiftUI

struct InjurySelectView: View {
    let patientProfileId: UUID
    @EnvironmentObject var router: Router
    
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
        ZStack(alignment: .bottom) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    section(title: "Ligaments", items: ligaments)
                    section(title: "Tendons", items: tendons)
                    section(title: "Knee Replacement Recovery", items: kneeReplacement)
                }
                .padding(.top, RRSpace.pageTop)
                .padding(.bottom, 120)
            }
            
            PTTabBar(selected: .dashboard) { tab in
                switch tab {
                case .dashboard:
                    router.go(.patientList)
                case .settings:
                    router.go(.ptSettings)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .rrPageBackground()
        .navigationTitle("Select Injury")
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
                                router.go(.ptJourneyMap(patientProfileId: patientProfileId, planId: nil))
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

