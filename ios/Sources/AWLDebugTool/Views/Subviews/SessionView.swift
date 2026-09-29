//
//  SessionView.swift
//  AWLDebugTool
//

import SwiftUI

struct SessionView: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        Section {
            if !sessionManager.tokens.isEmpty {
                ForEach(sessionManager.tokens, id: \.label) { tokenModel in
                    TokenRow(tokenModel: tokenModel)
                }
            } else {
                Text(LS.Session.notSetup)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text(LS.Headers.session)
        }
    }
}

private struct TokenRow: View {
    @ObservedObject var tokenModel: AWLDebugTool.TokenDebugModel
    @State private var tokenText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tokenModel.label)
                .font(.headline)

            HStack {
                Button {
                    UIPasteboard.general.string = tokenText
                } label: {
                    HStack {
                        Text(tokenText)
                        Image(systemName: "doc.on.doc")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    tokenModel.invalidateToken()
                } label: {
                    Text(tokenModel.isTokenInvalidating ? LS.Actions.invalidating : LS.Actions.invalidate)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .disabled(tokenModel.isTokenInvalidating)
            }
        }
        .padding(.vertical, 4)
        .task {
            tokenText = tokenModel.getTokenValue() ?? LS.Strings.unknownValue
        }
    }
}

#Preview {
    let m = SessionManager()
    m.tokens = [
        .init(label: "Test1", getToken: { "123" }),
        .init(label: "Test2", getToken: { "123123123123123131313123123123123" })
    ]
    
    return Form {
        SessionView(sessionManager: m)
    }
}
