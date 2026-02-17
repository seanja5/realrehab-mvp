//
//  MessagingView.swift
//  RealRehabPractice
//
//  iOS-style chat UI between PT and patient.
//

import SwiftUI

struct MessagingView: View {
    let ptProfileId: UUID
    let patientProfileId: UUID
    let otherPartyName: String
    let isPT: Bool  // true = current user is PT

    @EnvironmentObject var router: Router
    @State private var messages: [MessagingService.MessageRow] = []
    @State private var inputText: String = ""
    @State private var isLoading = true
    @State private var sendError: String?
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool

    private var senderRole: String { isPT ? "pt" : "patient" }
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { msg in
                            messageBubble(msg)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .onAppear { scrollProxy = proxy }
            }

            Divider()
            inputBar
        }
        .navigationTitle(otherPartyName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .swipeToGoBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .task { await loadMessages() }
        .refreshable { await loadMessages() }
        .onAppear {
            MessagingService.markThreadAsRead(ptProfileId: ptProfileId, patientProfileId: patientProfileId, isPT: isPT)
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: MessagingService.MessageRow) -> some View {
        let isFromMe = msg.sender_role == senderRole
        HStack(alignment: .bottom, spacing: 8) {
            if isFromMe { Spacer(minLength: 60) }
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                Text(msg.body)
                    .font(.body)
                    .foregroundStyle(isFromMe ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isFromMe ? Color.brandDarkBlue : Color(uiColor: .secondarySystemFill))
                    )
                Text(dateFormatter.string(from: msg.created_at))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isFromMe { Spacer(minLength: 60) }
        }
        .id(msg.id)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...6)
                .focused($isInputFocused)

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Color.brandDarkBlue : Color.gray)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows = try await MessagingService.fetchMessages(
                ptProfileId: ptProfileId,
                patientProfileId: patientProfileId
            )
            await MainActor.run {
                messages = rows
                if let last = rows.last {
                    scrollProxy?.scrollTo(last.id, anchor: .bottom)
                }
            }
        } catch {
            await MainActor.run { messages = [] }
        }
    }

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        sendError = nil

        let displayName: String? = await {
            if isPT {
                let pt = try? await PTService.myPTProfile()
                guard let first = pt?.first_name, let last = pt?.last_name else { return nil }
                return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
            } else {
                guard let profile = try? await AuthService.myProfile() else { return nil }
                return profile.first_name
            }
        }()

        do {
            let _ = try await MessagingService.sendMessage(
                ptProfileId: ptProfileId,
                patientProfileId: patientProfileId,
                senderRole: senderRole,
                senderDisplayName: displayName,
                body: text
            )
            await loadMessages()
            // Recipient notification: handled by Realtime subscription on recipient's device
        } catch {
            await MainActor.run {
                sendError = error.localizedDescription
                inputText = text
            }
        }
    }
}
