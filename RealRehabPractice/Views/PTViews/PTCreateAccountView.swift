import SwiftUI

struct PTCreateAccountView: View {
    @EnvironmentObject var router: Router

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var licenseNumber = ""
    @State private var npiNumber = ""
    @State private var practiceName = ""
    @State private var practiceAddress = ""
    @State private var specialization = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let specializationOptions = ["Orthopedics", "Sports", "Neuro", "Other"]

    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        !licenseNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !npiNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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

                    FormTextField(title: "Phone Number", placeholder: "Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    Divider()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Credentials")
                            .font(.rrTitle)
                            .foregroundStyle(.primary)

                        FormTextField(title: "License Number", placeholder: "License Number", text: $licenseNumber)

                        FormTextField(title: "NPI Number", placeholder: "NPI Number", text: $npiNumber)
                            .keyboardType(.numberPad)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Practice Information")
                            .font(.rrTitle)
                            .foregroundStyle(.primary)

                        FormTextField(title: "Practice Name", placeholder: "Practice Name", text: $practiceName)

                        FormTextField(title: "Practice Address", placeholder: "Practice Address", text: $practiceAddress)

                        FormMenuField(title: "Specialization", selection: $specialization, options: specializationOptions)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Password")
                            .font(.rrTitle)
                            .foregroundStyle(.primary)

                        FormSecureField(title: "Password", placeholder: "Password", text: $password)
                            .textContentType(.newPassword)

                        FormSecureField(title: "Confirm Password", placeholder: "Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                }
                .padding(.horizontal, 20)

                PrimaryButton(
                    title: isLoading ? "Creating..." : "Create Account",
                    isDisabled: !isFormValid || isLoading,
                    useLargeFont: true
                ) {
                    Task { await submit() }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .rrPageBackground()
        .navigationTitle("Create an Account")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .alert(isPresented: .constant(errorMessage != nil)) {
            Alert(
                title: Text("Sign Up Failed"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("OK")) {
                    errorMessage = nil
                }
            )
        }
    }

    @MainActor
    private func submit() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await AuthService.signUp(email: email, password: password)
            try await AuthService.signIn(email: email, password: password)

            try await AuthService.ensureProfile(
                defaultRole: "pt",
                firstName: firstName,
                lastName: lastName
            )

            let specializationValue = specialization.trimmingCharacters(in: .whitespaces).isEmpty ? nil : specialization
            let practiceNameValue = practiceName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : practiceName
            let practiceAddressValue = practiceAddress.trimmingCharacters(in: .whitespaces).isEmpty ? nil : practiceAddress

            _ = try await PTService.ensurePTProfile(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phone: phoneNumber,
                licenseNumber: licenseNumber,
                npiNumber: npiNumber,
                practiceName: practiceNameValue,
                practiceAddress: practiceAddressValue,
                specialization: specializationValue
            )

            router.go(.patientList)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Helpers

private func FormTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.rrCaption)
            .foregroundStyle(.secondary)

        TextField(placeholder, text: text)
            .font(.rrBody)
            .padding(14)
            .background(Color(uiColor: .secondarySystemFill))
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
            .background(Color(uiColor: .secondarySystemFill))
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
            Button("Clear") {
                selection.wrappedValue = ""
            }
        } label: {
            HStack {
                Text(selection.wrappedValue.isEmpty ? "Select" : selection.wrappedValue)
                    .font(.rrBody)
                    .foregroundStyle(selection.wrappedValue.isEmpty ? Color.secondary : Color.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

