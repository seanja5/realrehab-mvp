import SwiftUI

enum PatientTab {
    case dashboard
    case journey
    case settings
}

struct PatientTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var tabIndicatorNamespace

    var selected: PatientTab
    var onSelect: (PatientTab) -> Void
    var onAddTapped: () -> Void

    private let tabHeight: CGFloat = 60
    private var selectedForegroundColor: Color {
        colorScheme == .dark ? .white : Color.brandDarkBlue
    }
    private var selectedIndicatorColor: Color {
        colorScheme == .dark ? .white : Color.brandDarkBlue
    }

    private var selectedIndicatorId: String {
        switch selected {
        case .dashboard: return "dashboard"
        case .journey: return "journey"
        case .settings: return "settings"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            tabItem(
                id: "dashboard",
                icon: selected == .dashboard ? "doc.on.clipboard.fill" : "doc.on.clipboard",
                label: "Dashboard",
                selected: selected == .dashboard,
                action: { onSelect(.dashboard) }
            )

            tabItem(
                id: "journey",
                icon: selected == .journey ? "map.fill" : "map",
                label: "Journey",
                selected: selected == .journey,
                action: { onSelect(.journey) }
            )

            tabItem(
                id: "settings",
                icon: selected == .settings ? "gearshape.fill" : "gearshape",
                label: "Settings",
                selected: selected == .settings,
                action: { onSelect(.settings) }
            )

            addItem(action: onAddTapped)
        }
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(selectedIndicatorColor)
                .frame(width: 18, height: 2.5)
                .matchedGeometryEffect(id: selectedIndicatorId, in: tabIndicatorNamespace, isSource: false)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selected)
        }
        .frame(height: tabHeight)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(Color.rrSurface)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(id: String, icon: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: selected ? .semibold : .regular))
                    .frame(width: 22, height: 22)
                Text(label)
                    .font(.system(size: 11, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .frame(height: 14)
                // Always-present anchor — matchedGeometryEffect slides the overlay capsule here
                Color.clear
                    .frame(width: 18, height: 2.5)
                    .matchedGeometryEffect(id: id, in: tabIndicatorNamespace, isSource: true)
            }
            .foregroundStyle(selected ? selectedForegroundColor : Color.secondary.opacity(0.65))
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
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
                    .fill(
                        LinearGradient(
                            colors: [Color.brandDarkBlue, Color(red: 0.18, green: 0.36, blue: 0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: Color.brandDarkBlue.opacity(0.40), radius: 10, x: 0, y: 4)
                    .shadow(color: Color.brandDarkBlue.opacity(0.15), radius: 2, x: 0, y: 1)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .offset(x: -6, y: -22)
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

