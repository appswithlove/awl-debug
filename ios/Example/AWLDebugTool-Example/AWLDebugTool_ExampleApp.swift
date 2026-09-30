//
//  AWLDebugTool_ExampleApp.swift
//  AWLDebugTool-Example
//

import Security
import SwiftUI
import UserNotifications

#if DEBUG || STAGING
import AWLDebugTool
#endif

// MARK: - Notification delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Use this to display notifications while the app is active.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
#if DEBUG || STAGING
        if AWLDebugTool.processDeeplinkNotificationIfNeeded(response) {
            completionHandler()
            return
        }
#endif
        // handle your own notifications here
        completionHandler()
    }
}

// MARK: - App

@main
struct AWLDebugTool_ExampleApp: App {

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
#if DEBUG || STAGING
        AWLDebugTool.start(
            deeplinks: .init(
                deeplinks: [
                    .init(title: "test1", url: "myapp://test1"),
                    .init(title: "test2", url: "myapp://test2"),
                ],
                handler: .custom({ url in
                    print("The App will open: \(url)")
                })
            ),
            config: {
                var config = AWLDebugConfig()
                config.sessionProviders = [accessTokenProvider, refreshTokenProvider]
                config.triggers = [.threeFingerTap, .tripleTap]
                config.screenRecording = .init(isOnByDefault: true, maxDuration: .seconds(60))
                return config
            }()
        )
        AWLDebugTool.log("Example app started", tag: "App")
        AWLDebugTool.log("Example warning", level: .warn, tag: "App")
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if DEBUG || STAGING
                .includeDebugTool(customView: {
                    DebugPanelView()
                })
#endif
        }
    }
}

// MARK: - Debug panel

#if DEBUG || STAGING
class DebugPanelModel: ObservableObject {
    static let shared = DebugPanelModel()

    @Published var testBool: Bool = UserDefaults.standard.bool(forKey: "testBool") {
        didSet { UserDefaults.standard.set(testBool, forKey: "testBool") }
    }
}

struct DebugPanelView: View {
    @ObservedObject var model = DebugPanelModel.shared

    var body: some View {
        Group {
            Section {
                Button("Custom button 1") {
                    print("Custom button 1 Action")
                }
                Button("Custom button 2") {
                    print("Custom button 2 Action")
                }
                Button("Toggle login") {
                    let engine = AuthTestEngine.shared
                    engine.isLoggedIn ? engine.logout() : engine.login()
                }
                Button("Close panel") {
                    AWLDebugTool.close()
                }
            } header: {
                Text("Custom section header 1")
            }

            Section {
                Button("Save keychain test item") {
                    let item: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: "example-item",
                                                 kSecValueData: Data("secret".utf8)]
                    SecItemDelete(item as CFDictionary)
                    print("Keychain save:", SecItemAdd(item as CFDictionary, nil))
                }
                Button("Check keychain test item") {
                    let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: "example-item"]
                    print("Keychain item found:", SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess)
                }
            } header: {
                Text("Clear app data test")
            }

            Section {
                Text("Text \(model.testBool.description)")
                Toggle("Toggle", isOn: $model.testBool)
            } header: {
                Text("Custom section header 2")
            }
        }
    }
}
#endif
