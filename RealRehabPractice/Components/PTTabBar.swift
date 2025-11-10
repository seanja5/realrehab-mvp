import SwiftUI

enum PTTab {
    case dashboard
    case settings
}

struct PTTabBar: View {
    var selected: PTTab
    var onSelect: (PTTab) -> Void

    private let tabHeight: CGFloat = 72

    var body: some View {
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

// MARK: - Preview
struct PTTabBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PTTabBar(selected: .dashboard, onSelect: { _ in })
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Light")

            PTTabBar(selected: .settings, onSelect: { _ in })
                .preferredColorScheme(.dark)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Dark")
        }
    }
}

