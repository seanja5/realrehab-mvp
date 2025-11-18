import SwiftUI

enum PatientTab {
    case dashboard
    case journey
    case settings
}

struct PatientTabBar: View {
    var selected: PatientTab
    var onSelect: (PatientTab) -> Void
    var onAddTapped: () -> Void

    private let tabHeight: CGFloat = 60
    private let rrDarkBlue = Color.brandDarkBlue

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.black.opacity(0.08))

            HStack(spacing: 0) {
                tabItem(
                    icon: "doc.on.clipboard",
                    label: "Dashboard",
                    selected: selected == .dashboard,
                    action: { onSelect(.dashboard) }
                )

                tabItem(
                    icon: "map",
                    label: "Journey",
                    selected: selected == .journey,
                    action: { onSelect(.journey) }
                )

                tabItem(
                    icon: "gearshape",
                    label: "Settings",
                    selected: selected == .settings,
                    action: { onSelect(.settings) }
                )

                addItem(action: onAddTapped)
            }
            .frame(height: tabHeight)
            .frame(maxWidth: .infinity)
            .background(Color.white.ignoresSafeArea(edges: .bottom))
        }
    }

    private func tabItem(icon: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: icon == "doc.on.clipboard" ? 18 : 20, weight: .medium))
                    .frame(width: 20, height: 20)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .frame(height: 14)
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    private func addItem(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(rrDarkBlue)
                    .frame(width: 66, height: 66)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .offset(x: -9, y: -25)
            .frame(maxWidth: .infinity)
            .frame(height: tabHeight)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Add Device")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct PatientTabBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PatientTabBar(selected: .dashboard, onSelect: { _ in }, onAddTapped: {})
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Light")

            PatientTabBar(selected: .journey, onSelect: { _ in }, onAddTapped: {})
                .preferredColorScheme(.dark)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Dark")
        }
    }
}

