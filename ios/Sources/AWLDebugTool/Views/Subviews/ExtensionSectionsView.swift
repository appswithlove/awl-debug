import SwiftUI
import UIKit

/// Sections registered with `AWLDebugExtensions.register(_:)`, drawn like the panel's own rows.
struct ExtensionSectionsView: View {
    @ObservedObject var registry: ExtensionSectionRegistry

    var body: some View {
        ForEach(registry.sections) { section in
            ExtensionSectionView(section: section)
        }
    }
}

private struct ExtensionSectionView: View {
    @ObservedObject var section: AWLDebugExtensionSection

    var body: some View {
        if !section.items.isEmpty {
            Section {
                ForEach(section.items.indices, id: \.self) { index in
                    ExtensionItemRow(item: section.items[index])
                }
            }
        }
    }
}

private struct ExtensionItemRow: View {
    let item: AWLDebugExtensionItem

    var body: some View {
        switch item {
        case let .title(text, action):
            ExtensionTitleRow(text: text, action: action)
        case let .text(text, style, copyValue):
            ExtensionTextRow(text: text, style: style, copyValue: copyValue)
        case let .toggle(text, isOn, onChange):
            Toggle(text, isOn: Binding(get: { isOn }, set: { onChange($0) }))
        case let .link(text, badge, action):
            Button {
                Task { await ExtensionLink.open(action) }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text)
                    if let badge {
                        Text(badge)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// Bold text with the action at the trailing edge, or below it when large text needs the room.
private struct ExtensionTitleRow: View {
    let text: String
    let action: AWLDebugExtensionAction?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                title
                Spacer(minLength: 8)
                button
            }
            VStack(alignment: .leading, spacing: 8) {
                title
                button
            }
        }
    }

    private var title: some View {
        Text(text)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var button: some View {
        if let action {
            // Borderless, so only the button reacts, not the whole row.
            Button(action.title) {
                action.action()
            }
            .buttonStyle(.borderless)
            .disabled(!action.isEnabled)
        }
    }
}

private struct ExtensionTextRow: View {
    let text: String
    let style: AWLDebugTextStyle
    let copyValue: String?
    @State private var didCopy = false

    var body: some View {
        if let copyValue {
            Button {
                UIPasteboard.general.string = copyValue
                didCopy = true
                UIAccessibility.post(notification: .announcement, argument: LS.Panel.copied)
            } label: {
                HStack {
                    styled
                    Spacer(minLength: 8)
                    if didCopy {
                        Text(LS.Panel.copied)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityHint(LS.Panel.copyHint)
            .onChange(of: copyValue) { _ in
                didCopy = false
            }
        } else {
            styled
        }
    }

    private var styled: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
    }

    private var font: Font {
        switch style {
        case .primary: return .body
        case .secondary, .error: return .footnote
        case .monospace: return .footnote.monospaced()
        }
    }

    private var color: Color {
        switch style {
        case .primary, .monospace: return .primary
        case .secondary: return .secondary
        case .error: return .statusError
        }
    }
}

enum ExtensionLink {
    /// Closes the panel, then runs `action`, so what it shows opens over the app.
    @MainActor
    static func open(_ action: @MainActor () -> Void,
                     closePanel: @MainActor () async -> Void = { await AWLDebugExtensions.closePanel() }) async {
        await closePanel()
        action()
    }
}
