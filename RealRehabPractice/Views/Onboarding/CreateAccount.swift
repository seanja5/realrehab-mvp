import SwiftUI
import UIKit

// Shared colors for consistent styling
private let darkBlue    = Color(red: 0.04, green: 0.18, blue: 0.37)   // #0A2F5E
private let lightBlue   = Color(red: 0.18, green: 0.44, blue: 0.80)   // #2F6FCC
private let lightGrayBg = Color(uiColor: .systemGroupedBackground)
private let fieldFill   = Color(uiColor: .secondarySystemFill)        // ← this replaces 'secondarySystemFill'

struct CreateAccountView: View {
    @EnvironmentObject var router: Router
    @StateObject private var auth = AuthViewModel()
    
    // Color constants - matching WelcomeView
    private let darkBlue = Color(red: 0.1, green: 0.2, blue: 0.6)
    private let lightBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
    
    // Personal Info State
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    
    // Password State
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // DOB & Gender State
    @State private var dateOfBirth = Date()
    @State private var gender = "Select"
    
    // Surgery & PT Visit State
    @State private var dateOfSurgery = Date()
    @State private var lastPTVisit = Date()
    
    // Access Code State
    @State private var accessCode = ""
    @FocusState private var isAccessCodeFocused: Bool
    
    let genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say"]
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            VStack(spacing: 16) {
                                HStack(spacing: 12) {
                                    FormTextField(title: "First Name", placeholder: "First Name", text: $firstName)
                                        .textContentType(.givenName)
                                        .autocapitalization(.words)
                                        .frame(maxWidth: .infinity)
                                    FormTextField(title: "Last Name", placeholder: "Last Name", text: $lastName)
                                        .textContentType(.familyName)
                                        .autocapitalization(.words)
                                        .frame(maxWidth: .infinity)
                                }
                                
                                FormTextField(title: "Email", placeholder: "Email", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .textContentType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .onChange(of: email) { auth.email = $0 }
                                
                                FormTextField(title: "Phone Number", placeholder: "Phone Number", text: $phoneNumber)
                                    .keyboardType(.phonePad)
                                    .textContentType(.telephoneNumber)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Create a Password")
                                    .font(.rrTitle)
                                    .foregroundStyle(.primary)
                                
                                FormSecureField(title: "Password", placeholder: "Password", text: $password)
                                    .textContentType(.newPassword)
                                    .onChange(of: password) { auth.password = $0 }
                                
                                FormSecureField(title: "Confirm Password", placeholder: "Confirm Password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    FormDateField(title: "Date of Birth", date: $dateOfBirth)
                                        .frame(maxWidth: .infinity)
                                    
                                    FormMenuField(title: "Gender", selection: $gender, options: genderOptions)
                                        .frame(maxWidth: .infinity)
                                }
                                
                                HStack(spacing: 12) {
                                    FormDateField(title: "Date of Surgery", date: $dateOfSurgery)
                                        .frame(maxWidth: .infinity)
                                    
                                    FormDateField(title: "Last PT Visit", date: $lastPTVisit)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Access Code (Optional)")
                                    .font(.rrCaption)
                                    .foregroundStyle(.secondary)
                                
                                Text("If your Physical Therapist provided you with an 8-digit access code, enter it here to link your account.")
                                    .font(.rrCaption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Access Code")
                                        .font(.rrCaption)
                                        .foregroundStyle(.secondary)
                                    
                                    TextField("Enter 8-digit code", text: $accessCode)
                                        .font(.rrBody)
                                        .padding(14)
                                        .background(Color(fieldFill))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .focused($isAccessCodeFocused)
                                }
                                .id("accessCodeField")
                                .keyboardType(.numberPad)
                                .onChange(of: accessCode) { oldValue, newValue in
                                    // Limit to 8 digits and only allow numbers
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered.count <= 8 {
                                        accessCode = filtered
                                        auth.accessCode = filtered
                                    } else {
                                        accessCode = String(filtered.prefix(8))
                                        auth.accessCode = String(filtered.prefix(8))
                                    }
                                }
                                .onChange(of: isAccessCodeFocused) { oldValue, newValue in
                                    if newValue {
                                        // Scroll to access code field when it becomes focused
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            withAnimation {
                                                proxy.scrollTo("accessCodeField", anchor: .center)
                                            }
                                        }
                                    }
                                }
                            }
                            
                        }
                        .padding(.horizontal, 20)
                        
                        PrimaryButton(
                            title: auth.isLoading ? "Creating..." : "Create Account!",
                            isDisabled: !isFormValid || auth.isLoading,
                            useLargeFont: true,
                            action: {
                                Task {
                                    auth.firstName = firstName
                                    auth.lastName = lastName
                                    auth.email = email
                                    auth.password = password
                                    auth.phoneNumber = phoneNumber
                                    auth.dateOfBirth = dateOfBirth
                                    auth.dateOfSurgery = dateOfSurgery
                                    auth.lastPTVisit = lastPTVisit
                                    auth.gender = gender
                                    auth.accessCode = accessCode
                                    await auth.signUp()
                                    if auth.errorMessage == nil {
                                        router.go(.ptDetail)
                                    }
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Create an Account")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .alert(isPresented: .constant(auth.errorMessage != nil), content: {
            Alert(
                title: Text("Sign Up Failed"),
                message: Text(auth.errorMessage ?? ""),
                dismissButton: .default(Text("OK")) {
                    auth.errorMessage = nil
                }
            )
        })
    }
    
    // Validation
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !phoneNumber.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        gender != "Select" &&
        (accessCode.isEmpty || accessCode.count == 8)  // Access code must be 8 digits if provided
    }
}

// MARK: - Form Field Helpers

private func FormTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.rrCaption)
            .foregroundStyle(.secondary)
        
        TextField(placeholder, text: text)
            .font(.rrBody)
            .padding(14)
            .background(Color(fieldFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private func FormSecureField(title: String, placeholder: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.rrCaption)
            .foregroundStyle(.secondary)
        
        SecureField(placeholder, text: text)
            .font(.rrBody)
            .padding(14)
            .background(Color(fieldFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private func FormDateField(title: String, date: Binding<Date>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.rrCaption)
            .foregroundStyle(.secondary)
        
        HStack {
            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
            
            Spacer()
            
            Image(systemName: "calendar")
                .font(.rrCaption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(fieldFill))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private func FormMenuField(title: String, selection: Binding<String>, options: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.rrCaption)
            .foregroundStyle(.secondary)
        
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    selection.wrappedValue = option
                }
            }
        } label: {
            HStack {
                Text(selection.wrappedValue)
                    .font(.rrBody)
                    .foregroundStyle(selection.wrappedValue == "Select" ? Color.secondary : Color.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(fieldFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
