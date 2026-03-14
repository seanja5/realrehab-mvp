import SwiftUI

enum PTTab {
    case dashboard
    case settings
}

struct PTTabBar: View {
    var selected: PTTab
    var onSelect: (PTTab) -> Void

    private let tabHeight: CGFloat = 60

    var body: some View {
        HStack(spacing: 0) {
            tabItem(
                icon: selected == .dashboard ? "doc.on.clipboard.fill" : "doc.on.clipboard",
                label: "Dashboard",
                selected: selected == .dashboard
            ) {
                onSelect(.dashboard)
            }

            tabItem(
                icon: selected == .settings ? "gearshape.fill" : "gearshape",
                label: "Settings",
                selected: selected == .settings
            ) {
                onSelect(.settings)
            }
        }
        .frame(height: tabHeight)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(icon: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: selected ? .semibold : .regular))
                    .frame(width: 22, height: 22)
                Text(label)
                    .font(.system(size: 11, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .frame(height: 14)
                Capsule()
                    .fill(selected ? Color.brandDarkBlue : Color.clear)
                    .frame(width: 18, height: 2.5)
            }
            .foregroundStyle(selected ? Color.brandDarkBlue : Color.secondary.opacity(0.65))
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
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

