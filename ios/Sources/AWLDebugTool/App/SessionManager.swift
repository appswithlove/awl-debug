//
//  SessionManager.swift
//  AWLDebugTool
//

import Foundation
import UIKit
import UniformTypeIdentifiers

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var entries: [SessionEntry] = []
    @Published var isModuleShown = true

    var providers: [any AWLSessionProvider] = [] {
        didSet { entries = providers.map { SessionEntry(provider: $0) } }
    }

    /// Follows every provider's token until the calling task is cancelled (the panel closes).
    func observe() async {
        await withTaskGroup(of: Void.self) { group in
            for entry in entries {
                group.addTask { await entry.observe() }
            }
        }
    }
}

/// State of one provider in the panel: its live token and the action that is running.
@MainActor
final class SessionEntry: ObservableObject, Identifiable {
    enum Action {
        case edit, delete, invalidate, login, refresh, logout
    }

    let provider: any AWLSessionProvider
    @Published private(set) var token: String?
    @Published private(set) var runningAction: Action?
    @Published private(set) var errorMessage: String?

    init(provider: any AWLSessionProvider) {
        self.provider = provider
    }

    var label: String { provider.label }
    var isLoggedIn: Bool { token != nil }
    var canEdit: Bool { provider.setToken != nil }
    var canDelete: Bool { provider.setToken != nil && isLoggedIn }
    var canInvalidate: Bool { (provider.setToken != nil || provider.invalidate != nil) && isLoggedIn }
    var canLogin: Bool { provider.login != nil && !isLoggedIn }
    var canRefresh: Bool { provider.refresh != nil && isLoggedIn }
    var canLogout: Bool { provider.logout != nil && isLoggedIn }

    func observe() async {
        for await value in provider.token {
            token = value
        }
    }

    /// Replaces the token; an empty value deletes it.
    func edit(_ value: String) async {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        await perform(.edit) { try await self.provider.setToken?(trimmed.isEmpty ? nil : trimmed) }
    }

    func delete() async {
        await perform(.delete) { try await self.provider.setToken?(nil) }
    }

    /// With `setToken` the SDK writes `<token>.invalid`, otherwise it asks the app via `invalidate`.
    func invalidateToken() async {
        let token = token
        await perform(.invalidate) {
            if let setToken = self.provider.setToken, let token {
                try await setToken("\(token).invalid")
            } else {
                try await self.provider.invalidate?()
            }
        }
    }

    func login() async {
        await perform(.login) { try await self.provider.login?() }
    }

    func refresh() async {
        await perform(.refresh) { try await self.provider.refresh?() }
    }

    func logout() async {
        await perform(.logout) { try await self.provider.logout?() }
    }

    /// Copies the full token; the pasteboard forgets it after 60 s.
    func copyToken() {
        guard let token else { return }
        UIPasteboard.general.setItems([[UTType.plainText.identifier: token]],
                                      options: [.expirationDate: Date().addingTimeInterval(60)])
    }

    private func perform(_ action: Action, _ work: @escaping () async throws -> Void) async {
        guard runningAction == nil else { return }
        runningAction = action
        errorMessage = nil
        do {
            try await work()
        } catch {
            errorMessage = LS.Session.actionFailed(error.localizedDescription)
        }
        runningAction = nil
    }

    /// First 6 and last 4 characters; shorter tokens are hidden completely.
    static func masked(_ token: String) -> String {
        guard token.count > 10 else {
            return String(repeating: "•", count: token.count)
        }
        return "\(token.prefix(6))…\(token.suffix(4))"
    }
}

extension AWLDebugTool {
    /// Kept for 1.x integrations; the app asks `invalidatedIfNeeded` before using the token.
    @available(*, deprecated, message: "Use AWLTokenProvider in AWLDebugConfig.sessionProviders")
    public class TokenDebugModel: ObservableObject {
        @Published private(set) var isTokenInvalidating = false
        private let readToken: @MainActor () async -> String?
        private var invalidatedToken: String?
        let label: String

        /// - Parameter token: Read again every second while the panel is open, so it may await, e.g. a KMP `suspend` getter.
        public init(label: String, token: @MainActor @escaping () async -> String?) {
            self.label = label
            self.readToken = token
        }

        public convenience init(label: String, getToken: @MainActor @escaping () -> String?) {
            self.init(label: label, token: { getToken() })
        }

        var provider: AWLTokenProvider {
            let readToken = readToken
            return AWLTokenProvider(label: label,
                                    token: { await readToken() },
                                    invalidate: { [weak self] in await self?.invalidateToken() })
        }

        @MainActor
        func invalidateToken() {
            isTokenInvalidating = true
        }

        public func invalidatedIfNeeded(token: String?, invalidate: (String) -> String) -> String? {
            guard let token else { return nil }
            if isTokenInvalidating {
                if invalidatedToken == nil {
                    invalidatedToken = token
                }
                if token == invalidatedToken {
                    return invalidate(token)
                } else {
                    isTokenInvalidating = false
                    invalidatedToken = nil
                    return token
                }
            } else {
                return token
            }
        }
    }
}
