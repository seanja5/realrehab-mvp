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
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
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
                .font(.system(size: 17, weight: .bold))
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
                    .font(.headline)
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
                    .font(.system(size: 17, weight: .semibold))
                if let title {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .foregroundColor(Color.brandDarkBlue) // ✅ FIXED: explicitly declare Color
        .accessibilityLabel(title ?? "Back")
    }
}
