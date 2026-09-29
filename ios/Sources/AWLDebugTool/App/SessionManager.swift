//
//  SessionManager.swift
//  AWLDebugTool
//

import Foundation

public class SessionManager: ObservableObject {
    @Published var tokens: [AWLDebugTool.TokenDebugModel] = []
}

extension AWLDebugTool {
    public class TokenDebugModel: ObservableObject {
        @Published private(set) var isTokenInvalidating = false
        @Published private(set) var token: String?
        private var getToken: @MainActor () -> String?
        private var invalidatedToken: String?
        let label: String

        public init(label: String, getToken: @MainActor @escaping () -> String?) {
            self.label = label
            self.getToken = getToken
        }

        @MainActor
        func getTokenValue() -> String? {
            getToken()
        }

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
