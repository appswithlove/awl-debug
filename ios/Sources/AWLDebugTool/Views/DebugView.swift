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
    @ObservedObject private var permissionsManager = PermissionsManager()
    @ObservedObject private var networkReachabilityManager = NetworkReachabilityManager()
    
    @StateObject private var vm = DebugViewModel()

    @Environment(\.dismiss) var dismiss
    
    private var fcmToken: String?
    private let customView: (() -> any View)?
    
    var isDeleteLogsButtonDisabled: Bool {
        networkLogger.networkTraffic.isEmpty
    }
    
    func fetchNetworkLogsAsString() -> String {
        let df = DateFormatter()
        df.dateFormat = Constants.Date.dateFormatSecondary
        
        return networkLogger.networkTraffic
            .map { "\(df.string(from: $0.date)) \($0.method) (\($0.statusCode)) \($0.duration)ms - \($0.url)" }
            .joined(separator: "\n")
    }
    
    public init(fcmToken: String?, customView: (() -> any View)? = nil) {
        self.fcmToken = fcmToken
        self.customView = customView
    }
    
    public var body: some View {
        NavigationView {
            Form {
                AboutView(internetAccesStatusIcon: networkReachabilityManager.connectionStatusIcon.name,
                          internetAccesStatusColor: networkReachabilityManager.connectionStatusIcon.color)
                
                if customView != nil {
                    AnyView(customView!())
                }
                
                UserDefaultsView(isShowingDeleteUserDefaults: $vm.isShowingDeleteUserDefaults,
                                 showDeleteUserDefaultsAlert: vm.showDeleteUserDefaultsAlert)
                
                PermissionsView(
                    statuses: permissionsManager.statuses,
                    checkIfPermissionRequestTypeExistsInApp: { type in
                        permissionsManager.checkIfPermissionRequestTypeExistsInApp(type)
                    },
                    request: { type in
                        Task { await permissionsManager.request(type) }
                    },
                    openAppSettings: {
                        permissionsManager.openAppSettings()
                    }
                )
                
                FirebaseView()
                
                FCMPushTokenView(fcmToken: fcmToken)

                DeeplinksView(manager: deeplinksManager)

                ColorSchemeSectionView(preferredColorScheme: $vm.preferredColorScheme)
                FontSizeSectionView(preferredFontSize: $vm.preferredFontSize)

                Section {
                    Toggle(LS.Performance.showPerformanceOverlay, isOn: $vm.isPerformanceWidgetVisible)
                        
                    CPUView(cpuMonitor: debugTool.cpuMonitor)
                        .padding(.top, 24)
                        // .listRowSeparator(.hidden)
                    
                    RAMView(ramMonitor: debugTool.ramMonitor)
                        .padding(.top, 24)
                        .listRowSeparator(.hidden)
                    
                    MainThreadView(monitor: debugTool.mainThreadMonitor)
                        .padding(.top, 24)
                        .listRowSeparator(.hidden)
                } header: {
                    Text(LS.Performance.performanceSectionTitle)
                }
                
                LogsView(
                    networkLogger: networkLogger,
                    isDeleteLogsButtonDisabled: isDeleteLogsButtonDisabled,
                    showDeleteNetworkLogsAlert: vm.showDeleteNetworkLogsAlert,
                    isShowingDeleteNetworkLogs: $vm.isShowingDeleteNetworkLogs,
                    
                    deleteNetworkLogs: { networkLogger.deleteNetworkLogs() },
                    
                    isShowingDeleteUserDefaults: $vm.isShowingDeleteUserDefaults,
                    dismiss: { dismiss() },
                    filename: $vm.filename,
                    fetchNetworkLogsAsString: fetchNetworkLogsAsString,
                    showFileExporter: { logs in
                        vm.document.text = logs
                        vm.showFileExporter()
                    }
                )
                
                ScreenRecordingView(isScreenRecordingOn: $screenRecorder.isScreenRecordingOn,
                                    isScreenRecordingOnByDefault: $screenRecorder.isScreenRecordingOnByDefault,
                                    exportLastVideo: screenRecorder.exportLastVideo,
                                    isExportingVideo: screenRecorder.isExportingVideo,
                                    exportCurrentVideo: screenRecorder.exportCurrentVideo,
                                    maxVideoDuration: $screenRecorder.maxVideoDuration)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(LS.Strings.appName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text(LS.Headers.btnClose)
                    }
                }
            }
        }
        .fileExporter(isPresented: $vm.isShowingFileExporter,
                      document: vm.document,
                      contentType: .plainText,
                      defaultFilename: vm.filename
        ) { result in
            switch result {
            case .success(let file):
                print("\(LS.logWatermark) \(file)")
            case .failure(let error):
                print("\(LS.logWatermark) \(error)")
            }
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
