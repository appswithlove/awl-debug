import SwiftUI
import UIKit

/// How to set up a module the app has not configured yet: title, explanation and a copyable code snippet.
struct SetupHint: View {
    let title: String
    let message: String
    let snippet: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Text(snippet)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize()
                    .padding(8)
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            Button {
                UIPasteboard.general.string = snippet
            } label: {
                Label(LS.Panel.copyCode, systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}
