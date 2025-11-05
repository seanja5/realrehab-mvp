import SwiftUI

struct PTDetailView: View {
    @EnvironmentObject var router: Router
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpace.section) {
                // PT Card
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .overlay(
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Derek Samuel")
                                .font(.rrTitle)
                                .foregroundStyle(.primary)
                            
                            Text("Phone: (555) 123-4567")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                            Text("Email: derek.samuel@example.com")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    )
                    .frame(minHeight: 110)
                    .padding(.horizontal, 16)
                    .padding(.top, RRSpace.pageTop)
                
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                
                // Current Rehab Plan section
                VStack(alignment: .leading, spacing: RRSpace.stack) {
                    Text("Current Rehab Plan")
                        .font(.rrTitle)
                        .padding(.horizontal, 16)
                    
                    // Gray landscape box - tappable
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.go(.rehabOverview)
                        }
                        .padding(.horizontal, 16)
                    
                    // ACL Rehab text below box
                    Text("ACL Rehab")
                        .font(.rrBody)
                        .foregroundStyle(.primary)
                        .padding(.top, 10)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.go(.rehabOverview)
                        }
                }
                .padding(.top, 4)
                
                Spacer(minLength: 24)
            }
        }
        .rrPageBackground()
        .navigationTitle("Your Physical Therapist")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}

