import Foundation

/// One token source of the app, shown in the Session module (for example "Access Token").
///
/// Only `label` and `token` are required. Every action the provider leaves `nil` is hidden in the panel.
public protocol AWLSessionProvider {
    var label: String { get }
    /// The current token, then every change (`nil` = logged out). Read while the panel is open.
    var token: AsyncStream<String?> { get }
    /// Replaces the token; `nil` deletes it. Enables "Edit", "Delete" and "Invalidate" (writes `<token>.invalid`).
    var setToken: (@Sendable (String?) async throws -> Void)? { get }
    /// Makes the token invalid so the next request gets a 401. Used for "Invalidate" when `setToken` is `nil`.
    var invalidate: (@Sendable () async throws -> Void)? { get }
    var login: (@Sendable () async throws -> Void)? { get }
    var refresh: (@Sendable () async throws -> Void)? { get }
    var logout: (@Sendable () async throws -> Void)? { get }
}

public extension AWLSessionProvider {
    var setToken: (@Sendable (String?) async throws -> Void)? { nil }
    var invalidate: (@Sendable () async throws -> Void)? { nil }
    var login: (@Sendable () async throws -> Void)? { nil }
    var refresh: (@Sendable () async throws -> Void)? { nil }
    var logout: (@Sendable () async throws -> Void)? { nil }
}

/// A provider for apps that can read the token on demand, for example a KMP `suspend` getter.
/// The token is read again every `pollInterval` while the panel is open.
public struct AWLTokenProvider: AWLSessionProvider {
    public let label: String
    public let setToken: (@Sendable (String?) async throws -> Void)?
    public let invalidate: (@Sendable () async throws -> Void)?
    public let login: (@Sendable () async throws -> Void)?
    public let refresh: (@Sendable () async throws -> Void)?
    public let logout: (@Sendable () async throws -> Void)?
    private let readToken: @Sendable () async -> String?
    private let pollInterval: Duration

    public init(label: String,
                token: @escaping @Sendable () async -> String?,
                pollInterval: Duration = .seconds(1),
                setToken: (@Sendable (String?) async throws -> Void)? = nil,
                invalidate: (@Sendable () async throws -> Void)? = nil,
                login: (@Sendable () async throws -> Void)? = nil,
                refresh: (@Sendable () async throws -> Void)? = nil,
                logout: (@Sendable () async throws -> Void)? = nil) {
        self.label = label
        self.readToken = token
        self.pollInterval = pollInterval
        self.setToken = setToken
        self.invalidate = invalidate
        self.login = login
        self.refresh = refresh
        self.logout = logout
    }

    public var token: AsyncStream<String?> {
        let readToken = readToken
        let pollInterval = pollInterval
        return AsyncStream { continuation in
            let task = Task {
                var last: String??
                while !Task.isCancelled {
                    let value = await readToken()
                    if last != .some(value) {
                        last = .some(value)
                        continuation.yield(value)
                    }
                    try? await Task.sleep(for: pollInterval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
