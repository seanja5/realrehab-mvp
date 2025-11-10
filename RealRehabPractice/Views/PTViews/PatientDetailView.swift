import SwiftUI

struct PatientDetailView: View {
    @EnvironmentObject var router: Router
    @State private var notes: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: RRSpace.section) {
                    Text("Sean Andrews")
                        .font(.rrHeadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, RRSpace.pageTop)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    Text("DOB: 07/21/03   •   Gender: M")
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                        .overlay(
                            HStack {
                                Text("Recent Appointments")
                                    .font(.rrTitle)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("11/4/25")
                                    .font(.rrBody)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                        )
                        .frame(minHeight: 110)
                        .padding(.horizontal, 16)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        Text("Current Rehab Plan")
                            .font(.rrTitle)
                        
                        SecondaryButton(title: "Select Rehab Plan") {
                            router.go(.ptCategorySelect)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        Text("Notes")
                            .font(.rrTitle)
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                            .overlay(
                                ZStack(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text("Tap to add notes…")
                                            .font(.rrBody)
                                            .foregroundStyle(.secondary)
                                            .padding(16)
                                    }
                                    
                                    TextEditor(text: $notes)
                                        .font(.rrBody)
                                        .padding(12)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                }
                            )
                            .frame(minHeight: 180)
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 24)
                }
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}

