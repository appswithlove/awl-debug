//
//  DeeplinksView.swift
//  AWLDebugTool
//

import SwiftUI

struct DeeplinksView: View {
    @ObservedObject var manager: DeeplinksManager

    @State private var isAddingDeeplink = false

    var body: some View {
        Section {
            if manager.developerDeeplinks.isEmpty && manager.testerDeeplinks.isEmpty {
                Text(LS.Deeplinks.empty)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }

            ForEach(manager.developerDeeplinks) { deeplink in
                deeplinkRow(deeplink, isDeveloper: true)
            }

            ForEach(manager.testerDeeplinks) { deeplink in
                deeplinkRow(deeplink, isDeveloper: false)
            }
            .onDelete { manager.remove(at: $0) }

            Button {
                isAddingDeeplink = true
            } label: {
                Label(LS.Deeplinks.addDeeplink, systemImage: "plus.circle")
            }
            .sheet(isPresented: $isAddingDeeplink) {
                AddDeeplinkView(
                    onAdd: { title, url in manager.add(title: title, url: url) },
                    onDismiss: { isAddingDeeplink = false }
                )
            }
        } header: {
            Text(LS.Deeplinks.sectionTitle)
        }
    }

    @ViewBuilder
    private func deeplinkRow(_ deeplink: AWLDeeplink, isDeveloper: Bool) -> some View {
        NavigationLink {
            FireDeeplinkView(deeplink: deeplink, manager: manager)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(deeplink.title)
                        .foregroundStyle(Color(UIColor.label))
                    Text(deeplink.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isDeveloper ? "lock" : "person")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
    }
}
