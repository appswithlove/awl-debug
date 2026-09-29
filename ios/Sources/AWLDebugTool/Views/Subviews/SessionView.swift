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
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tokenModel.label)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(tokenModel.token == nil ? Color.gray : Color.green)
                    .frame(width: 8, height: 8)
                Text(tokenModel.token == nil ? LS.Session.loggedOut : LS.Session.loggedIn)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    UIPasteboard.general.string = tokenModel.token
                } label: {
                    HStack {
                        Text(displayedToken)
                        Image(systemName: "doc.on.doc")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
                .buttonStyle(.borderless)
                .disabled(tokenModel.token == nil)
                .accessibilityLabel(LS.Actions.copy)

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .disabled(tokenModel.token == nil)
                .accessibilityLabel(isRevealed ? LS.Session.hide : LS.Session.reveal)

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
            // Live while visible: the app's token changes (login, refresh, logout) show up without reopening.
            while !Task.isCancelled {
                await tokenModel.refresh()
                try? await Task.sleep(nanoseconds: AWLDebugTool.TokenDebugModel.refreshInterval)
            }
        }
    }

    private var displayedToken: String {
        guard let token = tokenModel.token else { return LS.Strings.unknownValue }
        return isRevealed ? token : AWLDebugTool.TokenDebugModel.masked(token)
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
