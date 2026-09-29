//
//  AddDeeplinkView.swift
//  AWLDebugTool
//

import SwiftUI

struct AddDeeplinkView: View {
    let onAdd: (String, String) -> Void
    let onDismiss: () -> Void

    @State private var title = ""
    @State private var url = ""

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty ||
        url.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(LS.Deeplinks.titlePlaceholder, text: $title)
                    TextField(LS.Deeplinks.urlPlaceholder, text: $url)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(LS.Deeplinks.addDeeplink)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LS.Headers.btnClose) { onDismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LS.Alert.btnOK) {
                        onAdd(title.trimmingCharacters(in: .whitespaces),
                              url.trimmingCharacters(in: .whitespaces))
                        onDismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }
}
