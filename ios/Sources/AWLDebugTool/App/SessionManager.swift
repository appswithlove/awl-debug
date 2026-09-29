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
        /// How often the panel reads the token again while it shows it.
        static let refreshInterval: UInt64 = 1_000_000_000

        @Published private(set) var isTokenInvalidating = false
        @Published private(set) var token: String?
        private let readToken: @MainActor () async -> String?
        private var invalidatedToken: String?
        let label: String

        /// - Parameter token: Read again every second while the panel shows it, so it may await, e.g. a KMP `suspend` getter.
        public init(label: String, token: @MainActor @escaping () async -> String?) {
            self.label = label
            self.readToken = token
        }

        public convenience init(label: String, getToken: @MainActor @escaping () -> String?) {
            self.init(label: label, token: { getToken() })
        }

        @MainActor
        func refresh() async {
            let value = await readToken()
            if value != token {
                token = value
            }
        }

        /// First 6 and last 4 characters; shorter tokens are hidden completely.
        static func masked(_ token: String) -> String {
            guard token.count > 10 else {
                return String(repeating: "•", count: token.count)
            }
            return "\(token.prefix(6))…\(token.suffix(4))"
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
