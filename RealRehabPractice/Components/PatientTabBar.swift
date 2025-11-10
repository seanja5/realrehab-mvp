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

    private let tabHeight: CGFloat = 72
    private let circleSize: CGFloat = 64
    private let rrDarkBlue = Color.brandDarkBlue

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Divider()
                    .background(Color.black.opacity(0.08))

                HStack(spacing: 0) {
                    tabItem(
                        icon: "doc.on.clipboard",
                        label: "Dashboard",
                        selected: selected == .dashboard
                    ) {
                        onSelect(.dashboard)
                    }

                    tabItem(
                        icon: "map",
                        label: "Journey",
                        selected: selected == .journey
                    ) {
                        onSelect(.journey)
                    }

                    tabItem(
                        icon: "gearshape",
                        label: "Settings",
                        selected: selected == .settings
                    ) {
                        onSelect(.settings)
                    }
                }
                .frame(height: tabHeight)
                .frame(maxWidth: .infinity)
                .background(Color.white.ignoresSafeArea(edges: .bottom))
            }

            Button(action: onAddTapped) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(width: circleSize, height: circleSize)
                    .background(
                        Circle()
                            .fill(rrDarkBlue)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }

    private func tabItem(icon: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
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

