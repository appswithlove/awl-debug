//
//  AWLDebugTool_ExampleApp.swift
//  AWLDebugTool-Example
//
//  Created by Alain Stulz on 21.03.2024.
//

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
            isScreenRecordingOn: true,
            deeplinks: .init(
                deeplinks: [
                    .init(title: "test1", url: "myapp://test1"),
                    .init(title: "test2", url: "myapp://test2"),
                ],
                handler: .custom({ url in
                    print("The App will open: \(url)")
                })
            ),
            tokens: [
                accessTokenDebugModel,
                refreshTokenDebugModel
            ]
        )
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
                Button("Close panel") {
                    AWLDebugTool.close()
                }
            } header: {
                Text("Custom section header 1")
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
