//
//  DebugView.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 07.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import SwiftUI

public struct DebugView: View {
    @ObservedObject private var debugTool = AWLDebugTool.shared
    @ObservedObject private var networkLogger = AWLDebugTool.shared.networkLogger
    @ObservedObject private var screenRecorder = AWLDebugTool.shared.screenRecorder
    @ObservedObject private var deeplinksManager = AWLDebugTool.shared.deeplinksManager
    @ObservedObject private var sessionManager = AWLDebugTool.shared.sessionManager
    @StateObject private var permissionsManager = PermissionsManager()
    @StateObject private var networkReachabilityManager = NetworkReachabilityManager()
    @ObservedObject private var appLogs = AWLDebugTool.shared.appLogs
    @ObservedObject private var performance = AWLDebugTool.shared.performance
    
    @StateObject private var vm = DebugViewModel()
    @AppStorage(Constants.UserDefaultsKey.versionOverlayVisible) private var isVersionOverlayVisible = true

    private var fcmToken: String?
    private let customView: (() -> any View)?

    public init(fcmToken: String?, customView: (() -> any View)? = nil) {
        self.fcmToken = fcmToken
        self.customView = customView
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                AboutView(isOnline: networkReachabilityManager.isConnected)

                RemoteReportingView(state: RemoteReporting.shared.panel)

                if VersionOverlayPresenter.shared.isAvailable {
                    Section {
                        Toggle(LS.VersionOverlay.toggle, isOn: $isVersionOverlayVisible)
                            .onChange(of: isVersionOverlayVisible) { _ in
                                VersionOverlayPresenter.shared.update()
                            }
                    }
                }

                FeedbackEntryView()
                
                // Fixed order, the same on Android: App-Info, Send feedback, Logs, Network, Performance, Permissions, Accessibility,
                // Deeplinks, Session, FCM, Screen Recording, Clear App Data, Test Crashes, custom modules.

                Section {
                    PanelModuleRow(title: LS.AppLogs.title, isActive: appLogs.isRecording) {
                        AppLogsView(store: appLogs)
                    }
                    PanelModuleRow(title: LS.Strings.logs, isActive: networkLogger.didStart) {
                        LogsListView()
                    }
                    PanelModuleRow(title: LS.Performance.performanceSectionTitle,
                                   isActive: performance.isMeasuring || vm.isPerformanceWidgetVisible) {
                        PerformanceView(performance: performance,
                                        isOverlayVisible: $vm.isPerformanceWidgetVisible,
                                        debugTool: debugTool)
                    }
                    PanelModuleRow(title: LS.Headers.permissions) {
                        PermissionsView(manager: permissionsManager)
                    }
                    PanelModuleRow(title: LS.Settings.accessibility,
                                   isActive: vm.preferredColorScheme != .auto || vm.preferredFontSize != .system) {
                        AccessibilityView(preferredColorScheme: $vm.preferredColorScheme,
                                          preferredFontSize: $vm.preferredFontSize)
                    }
                    PanelModuleRow(title: LS.Deeplinks.sectionTitle) {
                        DeeplinksView(manager: deeplinksManager)
                    }
                    SessionView(sessionManager: sessionManager)
                }

                FCMPushTokenView(fcmToken: fcmToken)

                Section {
                    PanelModuleRow(title: LS.Headers.screenRecording, isActive: screenRecorder.isOn) {
                        ScreenRecordingView(model: screenRecorder)
                    }
                    PanelModuleRow(title: LS.ClearData.title) {
                        UserDefaultsView(appGroupIdentifiers: debugTool.appGroupIdentifiers)
                    }
                    PanelModuleRow(title: LS.Headers.testCrashes) {
                        FirebaseView()
                    }
                }

                if let customView {
                    AnyView(customView())
                }
            }
            .panelPage(LS.Strings.appName)
        }
        .task(id: sessionManager.entries.map(\.id)) {
            // Live while the panel is open: login, refresh and logout show up without reopening.
            await sessionManager.observe()
        }
        .onAppear {
            screenRecorder.isDebugPanelVisible = true
        }
        .onDisappear {
            screenRecorder.isDebugPanelVisible = false
        }
    }
    
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView(fcmToken: "qwert1234", customView: {
            Group {
                Section {
                    Button("Custom button") {
                        print("Custom button Action")
                    }
                    Toggle("Custom toggle", isOn: .constant(true))
                } header: {
                    Text("Custom section header 1")
                }
            }
        })
    }
}
