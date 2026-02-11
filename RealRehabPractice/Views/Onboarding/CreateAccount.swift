import SwiftUI
import UIKit

private let fieldFill = Color(uiColor: .secondarySystemFill)

enum AccountType: String, CaseIterable {
    case patient = "Patient"
    case physicalTherapist = "Physical Therapist"
}

struct CreateAccountView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: SessionContext
    @StateObject private var auth = AuthViewModel()

    // Account type - user must select before creating
    @State private var accountType: AccountType?
    @State private var accountTypeSelection = "Select"

    // Shared state
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // Patient-only state
    @State private var dateOfBirth = Date()
    @State private var gender = "Select"
    @State private var dateOfSurgery = Date()
    @State private var lastPTVisit = Date()
    @State private var accessCode = ""
    @FocusState private var patientFocusedField: PatientField?
    enum PatientField: Hashable {
        case firstName, lastName, email, phone, password, confirmPassword, dob, gender, surgery, lastPT, accessCode
    }

    // PT-only state
    @State private var licenseNumber = ""
    @State private var npiNumber = ""
    @State private var practiceName = ""
    @State private var practiceAddress = ""
    @State private var specialization = ""
    @FocusState private var ptFocusedField: PTField?
    enum PTField: Hashable {
        case firstName, lastName, email, phone, password, confirmPassword, license, npi
    }

    @State private var ptErrorMessage: String?
    @State private var ptIsLoadingState = false
    @State private var showValidationErrors = false
    @State private var firstInvalidPatientFieldId: String?
    @State private var firstInvalidPTFieldId: String?

    let genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say"]
    private let specializationOptions = ["Orthopedics", "Sports", "Neuro", "Other"]

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            // Type of Account dropdown - always visible, required first
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Type of Account")
                                    .font(.rrCaption)
                                    .foregroundStyle(.secondary)
                                CreateAccountMenuField(
                                    selection: $accountTypeSelection,
                                    options: AccountType.allCases.map(\.rawValue),
                                    hasError: showValidationErrors && accountType == nil,
                                    allowClear: false
                                ) {
                                    accountTypeSelection = $0
                                    if let type = AccountType(rawValue: $0) {
                                        accountType = type
                                    } else {
                                        accountType = nil
                                    }
                                }
                            }
                            .id("accountTypeField")
                            .onChange(of: accountTypeSelection) { _, newValue in
                                if let type = AccountType(rawValue: newValue) {
                                    accountType = type
                                } else {
                                    accountType = nil
                                }
                            }

                            if let type = accountType {
                                Divider()
                                if type == .patient {
                                    patientFields(proxy: proxy)
                                } else {
                                    ptFields(proxy: proxy)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        PrimaryButton(
                            title: (auth.isLoading || ptIsLoadingState) ? "Creating..." : "Create Account!",
                            isDisabled: !canCreateAccount || auth.isLoading || ptIsLoadingState,
                            useLargeFont: true,
                            action: { Task { await handleCreateAccount(proxy: proxy) } }
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
        .swipeToGoBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .alert("Sign Up Failed", isPresented: .constant(auth.errorMessage != nil || ptErrorMessage != nil)) {
            Button("OK") {
                auth.errorMessage = nil
                ptErrorMessage = nil
            }
        } message: {
            Text(auth.errorMessage ?? ptErrorMessage ?? "")
        }
    }


    @ViewBuilder
    private func patientFields(proxy: ScrollViewProxy) -> some View {
        let err = showValidationErrors
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                CreateAccountFormField(title: "First Name", placeholder: "First Name", text: $firstName, hasError: err && firstName.isEmpty)
                    .textContentType(.givenName)
                    .autocapitalization(.words)
                    .frame(maxWidth: .infinity)
                    .id("patient_firstName")
                CreateAccountFormField(title: "Last Name", placeholder: "Last Name", text: $lastName, hasError: err && lastName.isEmpty)
                    .textContentType(.familyName)
                    .autocapitalization(.words)
                    .frame(maxWidth: .infinity)
                    .id("patient_lastName")
            }
            CreateAccountFormField(title: "Email", placeholder: "Email", text: $email, hasError: err && email.isEmpty)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .onChange(of: email) { _, v in auth.email = v }
                .id("patient_email")
            CreateAccountFormField(title: "Phone Number", placeholder: "Phone Number", text: $phoneNumber, hasError: err && phoneNumber.isEmpty)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .id("patient_phone")

            Divider()
            VStack(alignment: .leading, spacing: 16) {
                Text("Create a Password")
                    .font(.rrTitle)
                    .foregroundStyle(.primary)
                CreateAccountSecureField(title: "Password", placeholder: "Password", text: $password, hasError: err && password.isEmpty)
                    .textContentType(.newPassword)
                    .onChange(of: password) { _, v in auth.password = v }
                    .id("patient_password")
                CreateAccountSecureField(title: "Confirm Password", placeholder: "Confirm Password", text: $confirmPassword, hasError: err && (confirmPassword.isEmpty || password != confirmPassword))
                    .textContentType(.newPassword)
                    .id("patient_confirmPassword")
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    CreateAccountDateField(title: "Date of Birth", date: $dateOfBirth, hasError: false)
                        .frame(maxWidth: .infinity)
                        .id("patient_dob")
                    CreateAccountMenuField(title: "Gender", selection: $gender, options: genderOptions, hasError: err && gender == "Select") { gender = $0 }
                        .frame(maxWidth: .infinity)
                        .id("patient_gender")
                }
                HStack(spacing: 12) {
                    CreateAccountDateField(title: "Date of Surgery", date: $dateOfSurgery, hasError: false)
                        .frame(maxWidth: .infinity)
                        .id("patient_surgery")
                    CreateAccountDateField(title: "Last PT Visit", date: $lastPTVisit, hasError: false)
                        .frame(maxWidth: .infinity)
                        .id("patient_lastPT")
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
                CreateAccountFormField(title: "Access Code", placeholder: "Enter 8-digit code", text: $accessCode, hasError: false)
                    .keyboardType(.numberPad)
                    .onChange(of: accessCode) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        accessCode = String(filtered.prefix(8))
                        auth.accessCode = accessCode
                    }
                    .id("patient_accessCode")
            }
        }
    }

    @ViewBuilder
    private func ptFields(proxy: ScrollViewProxy) -> some View {
        let err = showValidationErrors
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                CreateAccountFormField(title: "First Name", placeholder: "First Name", text: $firstName, hasError: err && firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .textContentType(.givenName)
                    .autocapitalization(.words)
                    .frame(maxWidth: .infinity)
                    .id("pt_firstName")
                CreateAccountFormField(title: "Last Name", placeholder: "Last Name", text: $lastName, hasError: err && lastName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .textContentType(.familyName)
                    .autocapitalization(.words)
                    .frame(maxWidth: .infinity)
                    .id("pt_lastName")
            }
            CreateAccountFormField(title: "Email", placeholder: "Email", text: $email, hasError: err && email.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .id("pt_email")
            CreateAccountFormField(title: "Phone Number", placeholder: "Phone Number", text: $phoneNumber, hasError: err && phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .id("pt_phone")
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                Text("Create a Password")
                    .font(.rrTitle)
                    .foregroundStyle(.primary)
                CreateAccountSecureField(title: "Password", placeholder: "Password", text: $password, hasError: err && password.isEmpty)
                    .textContentType(.newPassword)
                    .id("pt_password")
                CreateAccountSecureField(title: "Confirm Password", placeholder: "Confirm Password", text: $confirmPassword, hasError: err && (confirmPassword.isEmpty || password != confirmPassword))
                    .textContentType(.newPassword)
                    .id("pt_confirmPassword")
            }
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                Text("Credentials")
                    .font(.rrTitle)
                    .foregroundStyle(.primary)
                CreateAccountFormField(title: "License Number", placeholder: "License Number", text: $licenseNumber, hasError: err && licenseNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                    .id("pt_license")
                CreateAccountFormField(title: "NPI Number", placeholder: "NPI Number", text: $npiNumber, hasError: err && npiNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardType(.numberPad)
                    .id("pt_npi")
            }
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                Text("Practice Information (Optional)")
                    .font(.rrTitle)
                    .foregroundStyle(.primary)
                CreateAccountFormField(title: "Practice Name", placeholder: "Practice Name", text: $practiceName, hasError: false)
                CreateAccountFormField(title: "Practice Address", placeholder: "Practice Address", text: $practiceAddress, hasError: false)
                CreateAccountMenuField(title: "Specialization", selection: $specialization, options: specializationOptions, hasError: false) { specialization = $0 }
            }
        }
    }

    private var canCreateAccount: Bool {
        guard let type = accountType else { return false }
        switch type {
        case .patient:
            return isPatientFormValid
        case .physicalTherapist:
            return isPTFormValid
        }
    }

    private var isPatientFormValid: Bool {
        !firstName.isEmpty &&
            !lastName.isEmpty &&
            !email.isEmpty &&
            !phoneNumber.isEmpty &&
            !password.isEmpty &&
            password == confirmPassword &&
            gender != "Select" &&
            (accessCode.isEmpty || accessCode.count == 8)
    }

    private var isPTFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !email.trimmingCharacters(in: .whitespaces).isEmpty &&
            !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
            !password.isEmpty &&
            password == confirmPassword &&
            !licenseNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
            !npiNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func firstInvalidPatientField() -> String? {
        if firstName.isEmpty { return "patient_firstName" }
        if lastName.isEmpty { return "patient_lastName" }
        if email.isEmpty { return "patient_email" }
        if phoneNumber.isEmpty { return "patient_phone" }
        if password.isEmpty { return "patient_password" }
        if confirmPassword.isEmpty || password != confirmPassword { return "patient_confirmPassword" }
        if gender == "Select" { return "patient_gender" }
        if !accessCode.isEmpty && accessCode.count != 8 { return "patient_accessCode" }
        return nil
    }

    private func firstInvalidPTField() -> String? {
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty { return "pt_firstName" }
        if lastName.trimmingCharacters(in: .whitespaces).isEmpty { return "pt_lastName" }
        if email.trimmingCharacters(in: .whitespaces).isEmpty { return "pt_email" }
        if phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty { return "pt_phone" }
        if password.isEmpty { return "pt_password" }
        if confirmPassword.isEmpty || password != confirmPassword { return "pt_confirmPassword" }
        if licenseNumber.trimmingCharacters(in: .whitespaces).isEmpty { return "pt_license" }
        if npiNumber.trimmingCharacters(in: .whitespaces).isEmpty { return "pt_npi" }
        return nil
    }

    @MainActor
    private func handleCreateAccount(proxy: ScrollViewProxy) async {
        guard let type = accountType else {
            showValidationErrors = true
            withAnimation {
                proxy.scrollTo("accountTypeField", anchor: .center)
            }
            return
        }

        switch type {
        case .patient:
            guard isPatientFormValid else {
                showValidationErrors = true
                if let id = firstInvalidPatientField() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                return
            }
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
                if let bootstrap = await AuthService.resolveSessionForLaunch() {
                    session.profileId = bootstrap.profileId
                    session.ptProfileId = bootstrap.ptProfileId
                    router.go(.ptDetail)
                }
            }
            showValidationErrors = false

        case .physicalTherapist:
            guard isPTFormValid else {
                showValidationErrors = true
                if let id = firstInvalidPTField() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                return
            }
            await submitPT(proxy: proxy)
        }
    }

    @MainActor
    private func submitPT(proxy: ScrollViewProxy) async {
        ptErrorMessage = nil
        ptIsLoadingState = true
        defer { ptIsLoadingState = false }
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
            let ptProfileId = try await PTService.ensurePTProfile(
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
            session.ptProfileId = ptProfileId
            if let bootstrap = await AuthService.resolveSessionForLaunch() {
                session.profileId = bootstrap.profileId
                session.ptProfileId = bootstrap.ptProfileId
            }
            showValidationErrors = false
            router.go(.patientList)
        } catch {
            ptErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Form Field Helpers with optional error styling

private struct CreateAccountFormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var hasError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.rrCaption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .font(.rrBody)
                .padding(14)
                .background(fieldFill)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(hasError ? Color.red : Color.clear, lineWidth: 2)
                )
        }
    }
}

private struct CreateAccountSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var hasError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.rrCaption)
                .foregroundStyle(.secondary)
            SecureField(placeholder, text: $text)
                .font(.rrBody)
                .padding(14)
                .background(fieldFill)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(hasError ? Color.red : Color.clear, lineWidth: 2)
                )
        }
    }
}

private struct CreateAccountDateField: View {
    let title: String
    @Binding var date: Date
    var hasError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.rrCaption)
                .foregroundStyle(.secondary)
            HStack {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                Spacer()
                Image(systemName: "calendar")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(fieldFill)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(hasError ? Color.red : Color.clear, lineWidth: 2)
            )
        }
    }
}

private struct CreateAccountMenuField: View {
    let title: String?
    @Binding var selection: String
    let options: [String]
    var hasError: Bool = false
    var allowClear: Bool = true
    var onSelect: ((String) -> Void)?

    init(selection: Binding<String>, options: [String], hasError: Bool = false, allowClear: Bool = true, onSelect: ((String) -> Void)? = nil) {
        self.title = nil
        self._selection = selection
        self.options = options
        self.hasError = hasError
        self.allowClear = allowClear
        self.onSelect = onSelect
    }

    init(title: String, selection: Binding<String>, options: [String], hasError: Bool = false, allowClear: Bool = true, onSelect: @escaping (String) -> Void) {
        self.title = title
        self._selection = selection
        self.options = options
        self.hasError = hasError
        self.allowClear = allowClear
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                        onSelect?(option)
                    }
                }
                if allowClear && !options.contains("Select") {
                    Button("Clear") {
                        selection = ""
                        onSelect?("")
                    }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty || selection == "Select" ? "Select" : selection)
                        .font(.rrBody)
                        .foregroundStyle(selection.isEmpty || selection == "Select" ? Color.secondary : Color.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(fieldFill)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(hasError ? Color.red : Color.clear, lineWidth: 2)
                )
            }
        }
    }
}
