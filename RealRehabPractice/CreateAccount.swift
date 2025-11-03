import SwiftUI
import UIKit

// Shared colors for consistent styling
private let darkBlue    = Color(red: 0.04, green: 0.18, blue: 0.37)   // #0A2F5E
private let lightBlue   = Color(red: 0.18, green: 0.44, blue: 0.80)   // #2F6FCC
private let lightGrayBg = Color(uiColor: .systemGroupedBackground)
private let fieldFill   = Color(uiColor: .secondarySystemFill)        // ← this replaces 'secondarySystemFill'

struct CreateAccountView: View {
    @EnvironmentObject var router: Router
    
    // Color constants - matching WelcomeView
    private let darkBlue = Color(red: 0.1, green: 0.2, blue: 0.6)
    private let lightBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
    private let lightGrayBg = Color(red: 0.95, green: 0.95, blue: 0.95)
    
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
    
    // PT Info State
    @State private var ptFirstName = ""
    @State private var ptLastName = ""
    @State private var ptEmail = ""
    @State private var ptPhoneNumber = ""
    
    let genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say"]
    
    var body: some View {
        ZStack {
            lightGrayBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button
                VStack(spacing: 12) {
                    HStack {
                        Button(action: { router.go(.welcome) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Step indicator
                StepIndicator(current: 1, total: 3, showLabel: true)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        Text("Create an Account")
                            .font(.monospaced(.headline)())
                            .fontWeight(.bold)
                            .padding(.bottom, 8)
                        
                        VStack(spacing: 16) {
                            // Personal Information Section
                            VStack(spacing: 16) {
                                // First Name / Last Name
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
                                
                                FormTextField(title: "Phone Number", placeholder: "Phone Number", text: $phoneNumber)
                                    .keyboardType(.phonePad)
                                    .textContentType(.telephoneNumber)
                            }
                            
                            Divider()
                            
                            // Create a Password Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Create a Password")
                                    .font(.monospaced(.headline)())
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                FormSecureField(title: "Password", placeholder: "Password", text: $password)
                                    .textContentType(.newPassword)
                                
                                FormSecureField(title: "Confirm Password", placeholder: "Confirm Password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                            }
                            
                            Divider()
                            
                            // Date & Gender Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Date of Birth")
                                    .font(.monospaced(.headline)())
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                HStack(spacing: 12) {
                                    FormDateField(title: "Date of Birth", date: $dateOfBirth)
                                        .frame(maxWidth: .infinity)
                                    
                                    FormMenuField(title: "Gender", selection: $gender, options: genderOptions)
                                        .frame(maxWidth: .infinity)
                                }
                                
                                Text("Date of Surgery")
                                    .font(.monospaced(.headline)())
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .padding(.top, 8)
                                
                                HStack(spacing: 12) {
                                    FormDateField(title: "Date of Surgery", date: $dateOfSurgery)
                                        .frame(maxWidth: .infinity)
                                    
                                    FormDateField(title: "Last PT Visit", date: $lastPTVisit)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            
                            Divider()
                            
                            // Physical Therapist Info Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Physical Therapist Info")
                                    .font(.monospaced(.headline)())
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                HStack(spacing: 12) {
                                    FormTextField(title: "PT First Name", placeholder: "First Name", text: $ptFirstName)
                                        .textContentType(.givenName)
                                        .autocapitalization(.words)
                                        .frame(maxWidth: .infinity)
                                    FormTextField(title: "PT Last Name", placeholder: "Last Name", text: $ptLastName)
                                        .textContentType(.familyName)
                                        .autocapitalization(.words)
                                        .frame(maxWidth: .infinity)
                                }
                                
                                FormTextField(title: "PT Email", placeholder: "Email", text: $ptEmail)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .textContentType(.emailAddress)
                                    .autocorrectionDisabled()
                                
                                FormTextField(title: "PT Phone Number", placeholder: "Phone Number", text: $ptPhoneNumber)
                                    .keyboardType(.phonePad)
                                    .textContentType(.telephoneNumber)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Create Account button at the bottom of scroll content
                        PrimaryButton(
                            title: "Create Account!",
                            isDisabled: !isFormValid,
                            action: {
                                if isFormValid {
                                    router.go(.pairDevice)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .navigationBarHidden(true)
    }
    
    // Validation
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !phoneNumber.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        gender != "Select"
    }
}

// MARK: - Form Field Helpers

private func FormTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
        
        TextField(placeholder, text: text)
            .padding(14)
            .background(Color(fieldFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private func FormSecureField(title: String, placeholder: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
        
        SecureField(placeholder, text: text)
            .padding(14)
            .background(Color(fieldFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private func FormDateField(title: String, date: Binding<Date>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
        
        HStack {
            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
            
            Spacer()
            
            Image(systemName: "calendar")
                .font(.caption)
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
            .font(.caption)
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
                    .foregroundStyle(selection.wrappedValue == "Select" ? Color.secondary : Color.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(fieldFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
