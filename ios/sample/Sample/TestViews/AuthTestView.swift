//
//  AuthTestView.swift
//  Sample
//

#if AWL_DEBUG
import AWLDebugTool
#endif
import SwiftUI

#if AWL_DEBUG
let accessTokenProvider = AWLTokenProvider(
    label: "Access Token",
    token: { await AuthTestEngine.shared.accessToken },
    setToken: { token in await MainActor.run { AuthTestEngine.shared.accessToken = token } },
    login: { await AuthTestEngine.shared.login() },
    refresh: { _ = await AuthTestEngine.shared.refreshAccessToken() },
    logout: { await AuthTestEngine.shared.logout() }
)

let refreshTokenProvider = AWLTokenProvider(
    label: "Refresh Token",
    token: { await AuthTestEngine.shared.refreshToken },
    setToken: { token in await MainActor.run { AuthTestEngine.shared.refreshToken = token } }
)
#endif

extension AuthTestEngine {
    struct ApiPath {
        let apiLabel: String
        let response: ApiResponse
    }
    
    enum ApiResponse: String {
        case success
        case errorNoInternet
        case error401
    }
}

@MainActor
class AuthTestEngine: ObservableObject {
    static let shared = AuthTestEngine()
    private let logPrefix = "Auth: "
    
    @Published var isInternetOn = true
    @Published private(set) var resultPath: String?
    @Published var accessToken: String?
    @Published var refreshToken: String?
    private var fakeToken: String {
        Date.now.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))
    }
    
    var isLoggedIn: Bool {
        return accessToken != nil
    }
    
    private init() {}
    
    func login() {
        print(logPrefix + "login")
        accessToken = "access_token_" + fakeToken
        refreshToken = "refresh_" + fakeToken
    }
    
    func logout() {
        print(logPrefix + "logout")
        accessToken = nil
        refreshToken = nil
    }
    
    func testApiCall() {
        let results = processApiCall()
        resultPath = results.map({"\($0.apiLabel).\($0.response.rawValue)"})
            .joined(separator: " -> ")
        print(logPrefix + "result: " + (resultPath ?? ""))
    }
    
    private func processApiCall() -> [ApiPath] {
        let apiResult = ApiPath(apiLabel: "api", response: apiCall())
        var results = [apiResult]
        if apiResult.response == .error401 {
            let refreshResult = ApiPath(apiLabel: "refresh", response: refreshAccessToken())
            results.append(refreshResult)
            if refreshResult.response == .success {
                let newResults = processApiCall()
                results += newResults
            } else {
                // failed to refresh
            }
        } else {
            // everything fine
        }
        return results
    }
    
    private func apiCall() -> ApiResponse {
        print(logPrefix + "apiCall")
        return isAccessTokenValid() && isInternetOn ? .success : .error401
    }
    
    func refreshAccessToken() -> ApiResponse {
        print(logPrefix + "refreshAccessToken")
        guard isInternetOn else {
            return .errorNoInternet
        }
        
        if isRefreshTokenValid() {
            accessToken = "access_" + fakeToken
            return .success
        } else {
            logout()
            return .error401
        }
    }
    
    /// The debug panel's "Invalidate" writes `<token>.invalid`, which this fake backend rejects.
    private func isAccessTokenValid() -> Bool {
        accessToken.map { !$0.hasSuffix(".invalid") } ?? false
    }
    
    private func isRefreshTokenValid() -> Bool {
        refreshToken.map { !$0.hasSuffix(".invalid") } ?? false
    }
}

struct AuthTestView: View {
    @StateObject private var engine = AuthTestEngine.shared
    
    var body: some View {
        VStack {
            Text("Playground")
            
            HStack {
                Text("is Online")
                Toggle("", isOn: $engine.isInternetOn).labelsHidden()
            }
            
            HStack {
                Button("Login") {
                    engine.login()
                }
                
                Button("Logout") {
                    engine.logout()
                }
                
                Button("ApiCall") {
                    engine.testApiCall()
                }
            }
            
            Text(engine.isLoggedIn ? "Loged in" : "Loged out")
                .foregroundStyle(engine.isLoggedIn ? Color.green : Color.red)
            
            Text(engine.resultPath ?? "")
                .font(.caption2)
            
            Text("Tokens:")
            Text("access: \(engine.accessToken ?? "-")")
                .font(.caption2)
            Text("refresh: \(engine.refreshToken ?? "-")")
                .font(.caption2)
            
            Divider()
            Text("Auth road map:")
            Text("""
                   ↓
                Call API
                ↑    │
                │   2xx? ──yes─► Finish
                │    │no
                │   401? ──no──► Handle error
                │    │yes
                │ Refresh token
                │    │
                │   2xx? ──no──► 401? ──yes─► Logout
                │    │yes         └─────no──► Handle error
                │ Save token
                └────┘
                """)
            .font(.caption.monospaced())
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    AuthTestView()
}
