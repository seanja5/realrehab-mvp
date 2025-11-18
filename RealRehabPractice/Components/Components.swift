//
//  Components.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 11/2/25.
//

import SwiftUI

// MARK: - Brand Colors (shared)
extension Color {
    static let brandLightBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
    static let brandDarkBlue  = Color(red: 0.1, green: 0.2, blue: 0.6)
}

// MARK: - Primary (Filled) Button
struct PrimaryButton: View {
    let title: String
    var isDisabled: Bool = false
    var useLargeFont: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(useLargeFont ? .rrTitle : .rrBody)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(isDisabled ? Color.gray : .brandDarkBlue)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Secondary (Outline) Button
struct SecondaryButton: View {
    let title: String
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rrBody)
                .foregroundStyle(isDisabled ? Color.gray : .brandDarkBlue)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isDisabled ? Color.gray : .brandDarkBlue, lineWidth: 2)
                )
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Step Indicator (with label + connected dots)
struct StepIndicator: View {
    let current: Int
    let total: Int
    var showLabel: Bool = true

    private let active = Color.brandLightBlue
    private let inactive = Color.gray.opacity(0.3)

    var body: some View {
        VStack(spacing: 8) {
            if showLabel {
                Text("Step \(current)")
                    .font(.rrTitle)
            }

            HStack(spacing: 16) {
                ForEach(1...total, id: \.self) { step in
                    HStack(spacing: 0) {
                        Circle()
                            .fill(step <= current ? active : inactive)
                            .frame(width: 10, height: 10)

                        if step < total {
                            Rectangle()
                                .fill(step < current ? active : inactive)
                                .frame(width: 40, height: 2)
                                .padding(.horizontal, 6)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Back Button (Toolbar-compatible)
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var title: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            if let action { action() }
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.rrBody)
                if let title {
                    Text(title)
                        .font(.rrBody)
                }
            }
        }
        .foregroundColor(Color.brandDarkBlue) // ✅ FIXED: explicitly declare Color
        .accessibilityLabel(title ?? "Back")
    }
}

// MARK: - SearchBar
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.rrBody)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search")
    }
}

// MARK: - BodyPartCard
struct BodyPartCard: View {
    let title: String
    var image: Image? = nil
    var imageName: String? = nil
    var tappable: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            // Image block
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 160, height: 160)
                .overlay(
                    Group {
                        if let image = image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if let imageName = imageName {
                            Image(imageName, bundle: .main)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(systemName: "photo")
                                .font(.rrBody)
                                .foregroundStyle(.gray)
                        }
                    }
                )

            Text(title)
                .font(.rrCaption)
                .foregroundStyle(.primary)
                .frame(maxWidth: 160, alignment: .center)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if tappable { action?() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}
