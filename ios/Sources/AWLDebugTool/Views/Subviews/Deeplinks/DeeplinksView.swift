//
//  DeeplinksView.swift
//  AWLDebugTool
//

import SwiftUI

struct DeeplinksView: View {
    @ObservedObject var manager: DeeplinksManager

    @State private var isAddingDeeplink = false
    @State private var quickURL = ""
    @State private var isQuickURLInvalid = false

    var body: some View {
        Form {
            Section {
                QuickField
            }

            if manager.developerDeeplinks.isEmpty && manager.testerDeeplinks.isEmpty {
                Section {
                    Text(LS.Deeplinks.empty)
                        .foregroundStyle(.secondary)
                }
            }

            if !manager.developerDeeplinks.isEmpty {
                Section {
                    ForEach(manager.developerDeeplinks) { deeplink in
                        deeplinkRow(deeplink, isDeveloper: true)
                    }
                } header: {
                    Text(LS.Deeplinks.predefined)
                }
            }

            if !manager.testerDeeplinks.isEmpty {
                Section {
                    ForEach(manager.testerDeeplinks) { deeplink in
                        deeplinkRow(deeplink, isDeveloper: false)
                    }
                    .onDelete { manager.remove(at: $0) }
                } header: {
                    Text(LS.Deeplinks.saved)
                }
            }

            Section {
                Button {
                    isAddingDeeplink = true
                } label: {
                    Label(LS.Deeplinks.addDeeplink, systemImage: "plus.circle")
                }
            }
        }
        .panelPage(LS.Deeplinks.sectionTitle)
        .sheet(isPresented: $isAddingDeeplink) {
            AddDeeplinkView(
                onAdd: { title, url in manager.add(title: title, url: url) },
                onDismiss: { isAddingDeeplink = false }
            )
        }
    }

    @ViewBuilder
    private var QuickField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(LS.Deeplinks.input, text: $quickURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.go)
                .onSubmit(fireQuickURL)
                .onChange(of: quickURL) { _ in
                    isQuickURLInvalid = false
                }
            if isQuickURLInvalid {
                Text(LS.Deeplinks.invalid)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            HStack {
                Button(LS.Deeplinks.fireNow, action: fireQuickURL)
                    .buttonStyle(.borderedProminent)
                Button(LS.Deeplinks.save, action: saveQuickURL)
                    .buttonStyle(.bordered)
            }
            .disabled(quickURL.isEmpty || isQuickURLInvalid)
        }
        .padding(.vertical, 4)
    }

    private func fireQuickURL() {
        guard let url = DeeplinksManager.validURL(from: quickURL) else {
            isQuickURLInvalid = true
            return
        }
        manager.fire(url)
    }

    private func saveQuickURL() {
        guard let url = DeeplinksManager.validURL(from: quickURL) else {
            isQuickURLInvalid = true
            return
        }
        manager.add(title: url.absoluteString, url: url.absoluteString)
        quickURL = ""
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
                    .accessibilityHidden(true)
            }
        }
    }
}
