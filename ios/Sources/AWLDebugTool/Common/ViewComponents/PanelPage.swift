import SwiftUI

/// Title and Close button of the start page and every module page, so all pages look and close the same way.
/// Page actions (a "…" menu) come before Close, which is always the last item.
struct PanelPageModifier<Actions: View>: ViewModifier {
    let title: String
    let actions: () -> Actions

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    actions()
                    PanelCloseButton()
                }
            }
    }
}

extension View {
    /// Module page: title in the navigation bar and a Close button that closes the whole panel.
    func panelPage(_ title: String) -> some View {
        modifier(PanelPageModifier(title: title) { EmptyView() })
    }

    /// Module page with its own actions in the navigation bar, placed before Close.
    func panelPage<Actions: View>(_ title: String, @ViewBuilder actions: @escaping () -> Actions) -> some View {
        modifier(PanelPageModifier(title: title, actions: actions))
    }
}

/// Closes the panel; outside the panel (a page shown by the app itself) it dismisses the page.
struct PanelCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(LS.Headers.btnClose) {
            if AWLDebugTool.isOpen {
                AWLDebugTool.close()
            } else {
                dismiss()
            }
        }
    }
}

/// A module on the start page. Opens the module page; a green dot shows that the module is active.
struct PanelModuleRow<Destination: View>: View {
    let title: String
    var isActive = false
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 8) {
                Text(title)
                if isActive {
                    ActiveDot()
                }
            }
        }
        .accessibilityValue(isActive ? LS.Panel.active : "")
    }
}

/// The green "active" dot of the start page. VoiceOver reads the state from the row instead.
struct ActiveDot: View {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(.green)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
