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
                // One line when it fits, the providers below the title with large text.
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(LS.Headers.session)
                        Spacer()
                        statusDots
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LS.Headers.session)
                        statusDots
                    }
                }
            }
        }
    }
}

extension SessionView {
    private var statusDots: some View {
        FlowLayout {
            ForEach(sessionManager.entries) { entry in
                SessionStatusDot(entry: entry)
            }
        }
    }
}

/// Green while a token is there, grey without.
private struct SessionDot: View {
    let isLoggedIn: Bool
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(isLoggedIn ? Color.statusPositive : Color.gray)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct SessionStatusDot: View {
    @ObservedObject var entry: SessionEntry

    var body: some View {
        HStack(spacing: 4) {
            SessionDot(isLoggedIn: entry.isLoggedIn)
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
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(entry.label)
                        .font(.headline)
                    Spacer()
                    loginStatus
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.label)
                        .font(.headline)
                    loginStatus
                }
            }
            .accessibilityElement(children: .combine)

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
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(isRevealed ? LS.Session.hide : LS.Session.reveal)
                .disabled(!entry.isLoggedIn)
                Button {
                    entry.copyToken()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(LS.Actions.copy)
                .disabled(!entry.isLoggedIn)
            }
            .buttonStyle(.borderless)

            actions

            if let errorMessage = entry.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.statusError)
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

    private var loginStatus: some View {
        HStack(spacing: 4) {
            SessionDot(isLoggedIn: entry.isLoggedIn)
            Text(entry.isLoggedIn ? LS.Session.loggedIn : LS.Session.loggedOut)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Only the actions the app offers, and only those that fit the current state. Wraps to more rows as needed.
    private var actions: some View {
        FlowLayout {
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
