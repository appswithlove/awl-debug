//
//  SessionView.swift
//  AWLDebugTool
//

import SwiftUI

/// Start-page row: one status dot per provider, opens the detail page. Hidden without providers.
struct SessionView: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        if !sessionManager.entries.isEmpty {
            NavigationLink {
                SessionDetailView(sessionManager: sessionManager)
            } label: {
                HStack {
                    Text(LS.Headers.session)
                    Spacer()
                    ForEach(sessionManager.entries) { entry in
                        SessionStatusDot(entry: entry)
                    }
                }
            }
        }
    }
}

private struct SessionStatusDot: View {
    @ObservedObject var entry: SessionEntry

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(entry.isLoggedIn ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(entry.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.label): \(entry.isLoggedIn ? LS.Session.loggedIn : LS.Session.loggedOut)")
    }
}

struct SessionDetailView: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        Form {
            ForEach(sessionManager.entries) { entry in
                Section {
                    SessionCard(entry: entry)
                }
            }
        }
        .panelPage(LS.Headers.session)
    }
}

private struct SessionCard: View {
    @ObservedObject var entry: SessionEntry
    @State private var isRevealed = false
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var editedToken = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.label)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(entry.isLoggedIn ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(entry.isLoggedIn ? LS.Session.loggedIn : LS.Session.loggedOut)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(displayedToken)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .lineLimit(isRevealed ? nil : 1)
                    .textSelection(.enabled)
                Spacer()
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                }
                .accessibilityLabel(isRevealed ? LS.Session.hide : LS.Session.reveal)
                .disabled(!entry.isLoggedIn)
                Button {
                    entry.copyToken()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel(LS.Actions.copy)
                .disabled(!entry.isLoggedIn)
            }
            .buttonStyle(.borderless)

            actions

            if let errorMessage = entry.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
        .alert(LS.Session.editTitle(entry.label), isPresented: $isEditing) {
            TextField(LS.Session.pastePlaceholder, text: $editedToken)
            Button(LS.Session.cancel, role: .cancel) {}
            Button(LS.Session.confirm) {
                let value = editedToken
                Task { await entry.edit(value) }
            }
        }
        .alert(LS.Session.deleteTitle, isPresented: $isConfirmingDelete) {
            Button(LS.Session.cancel, role: .cancel) {}
            Button(LS.Session.delete, role: .destructive) {
                Task { await entry.delete() }
            }
        } message: {
            Text(LS.Session.deleteMessage(entry.label))
        }
    }

    /// Only the actions the app offers, and only those that fit the current state.
    private var actions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                if entry.canEdit {
                    actionButton(LS.Session.edit, action: .edit) {
                        editedToken = entry.token ?? ""
                        isEditing = true
                    }
                }
                if entry.canDelete {
                    actionButton(LS.Session.delete, action: .delete, role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
                if entry.canInvalidate {
                    actionButton(entry.runningAction == .invalidate ? LS.Actions.invalidating : LS.Actions.invalidate,
                                 action: .invalidate, role: .destructive) {
                        Task { await entry.invalidateToken() }
                    }
                }
                if entry.canLogin {
                    actionButton(LS.Session.login, action: .login) {
                        Task { await entry.login() }
                    }
                }
                if entry.canRefresh {
                    actionButton(LS.Session.refresh, action: .refresh) {
                        Task { await entry.refresh() }
                    }
                }
                if entry.canLogout {
                    actionButton(LS.Session.logout, action: .logout) {
                        Task { await entry.logout() }
                    }
                }
            }
        }
        .buttonStyle(.bordered)
    }

    private func actionButton(_ title: String, action: SessionEntry.Action, role: ButtonRole? = nil,
                              perform: @escaping () -> Void) -> some View {
        Button(role: role, action: perform) {
            HStack(spacing: 6) {
                if entry.runningAction == action {
                    ProgressView()
                }
                Text(title)
            }
        }
        .disabled(entry.runningAction != nil)
    }

    private var displayedToken: String {
        guard let token = entry.token else { return LS.Strings.unknownValue }
        return isRevealed ? token : SessionEntry.masked(token)
    }
}
