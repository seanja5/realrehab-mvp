import SwiftUI
import Supabase

struct WelcomeView: View {
    @EnvironmentObject var router: Router
    
    // Color constants matching the design
    private let lightBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
    private let darkBlue = Color(red: 0.1, green: 0.2, blue: 0.6)
    private let lightGrayBg = Color(red: 0.95, green: 0.95, blue: 0.95)
    
    var body: some View {
        ZStack {
            lightGrayBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Centered Title Section
                VStack(alignment: .center, spacing: 4) {
                    Text("Real")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundStyle(lightBlue)
                    Text("Rehab")
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundStyle(darkBlue)
                }
                
                Spacer()
                
                // Action Buttons - pinned to bottom
                VStack(spacing: 20) {
                    Button("Get Started!") {
                        router.go(.createAccount)
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(darkBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    Button("Log In") {
                        router.go(.home)
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(darkBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(darkBlue, lineWidth: 2)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .safeAreaPadding(.bottom)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            Task {
                do {
                    _ = try await SupabaseService.shared.client
                        .from("accounts")
                        .select()
                        .limit(1)
                        .execute()
                    print("✅ Supabase connection OK")
                } catch {
                    print("❌ Supabase error:", error)
                }
            }
        }
    }
}
