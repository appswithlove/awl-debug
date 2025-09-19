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
    @ObservedObject private var permissionsManager = PermissionsManager()
    
    @StateObject private var vm: DebugViewModel = .init()
    
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("isDarkModeOn") private var isDarkModeOn: Bool = false
    
    private var fcmToken: String?
    private let customView: (() -> any View)?
    
    var isDeleteLogsButtonDisabled: Bool {
        return networkLogger.networkTraffic.isEmpty ? true : false
    }
    
    func fetchNetworkLogsAsString() -> String {
        let df = DateFormatter()
        df.dateFormat = Constants.Date.dateFormatSecondary
        var result = ""
        for log in networkLogger.networkTraffic {
            let logAsString = "\(df.string(from: log.date)) \(log.method) (\(log.statusCode)) \(log.duration)ms - \(log.url)\n"
            result += logAsString
        }
        return result
    }
    
    public init(fcmToken: String?, customView: (() -> any View)? = nil) {
        self.fcmToken = fcmToken
        self.customView = customView
    }
    
    public var body: some View {
        NavigationView {
            Form {
                AboutView
                
                if customView != nil {
                    AnyView(customView!())
                }
                
                LogOptionsView
                
                UserDefaultsView
                
                PermissionsView
                
                FirebaseView
                
                FCMPushTokenView
                
                ScreenRecordingView

                SettingsView
            }
            .preferredColorScheme(isDarkModeOn ? .dark : .light)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(Constants.Strings.appName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text(Constants.Headers.btnClose)
                    }
                }
            }
        }
        .fileExporter(isPresented: $vm.isShowingFileExporter, document: vm.document, contentType: .plainText, defaultFilename: vm.filename) { result in
            switch result {
            case .success(let file):
                print(file)
            case .failure(let error):
                print(error)
            }
        }
        .onAppear {
            screenRecorder.isDebugPanelVisible = true
        }
        .onDisappear {
            screenRecorder.isDebugPanelVisible = false
        }
    }
    
    @ViewBuilder
    private var AboutView: some View {
        Section {
            Text("\(UIDevice.current.name)") +
            Text(" (\(UIDevice.current.systemVersion)") +
            Text(" - \(Bundle.main.infoDictionary?["DTSDKBuild"] as? String ?? "Unknown"))")
            Text("\(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "")") +
            Text(" \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")") +
            Text(" (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
        } header: {
            Text(Constants.Headers.aboutSection + " ") +
            Text(ISO8601DateFormatter().string(from: Date()))
        }
    }
    
    @ViewBuilder
    private var LogOptionsView: some View {
        Section {
            ShowNetworkLogsOption
            
            ProprietaryActionButton(text: Constants.Actions.clearNetworkLogs,
                                    iconName: Constants.Image.clear,
                                    iconColor: IconColor.deletion,
                                    isDisabled: isDeleteLogsButtonDisabled,
                                    action: { vm.showDeleteNetworkLogsAlert() })
            
            ExportNetworkLogsOption
        } header: {
            Text(Constants.Headers.logs)
        }
        .destructiveAlertViewModifier(isShowingAlert: $vm.isShowingDeleteNetworkLogs,
                                      title: Constants.Alert.deleteNLTitle,
                                      message: Constants.Alert.deleteNLMessage,
                                      action: { networkLogger.deleteNetworkLogs() })
        .destructiveAlertViewModifier(isShowingAlert: $vm.isShowingDeleteUserDefaults,
                                      title: Constants.Alert.deleteUDTitle,
                                      message: Constants.Alert.deleteUDMessage,
                                      action: { UserDefaults.standard.clearAppUserDefaults() })
        .textCase(nil)
    }
    
    @ViewBuilder
    private var ShowNetworkLogsOption: some View {
        NavigationLink {
            LogsView(onClose: { dismiss() })
        } label: {
            Text(Constants.Actions.showNetworkLogs)
        }
    }
    
    @ViewBuilder
    private var ExportNetworkLogsOption: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProprietaryActionButton(text: Constants.Actions.exportNetworkLogs,
                                    iconName: Constants.Image.export,
                                    iconColor: IconColor.action,
                                    isDisabled: isDeleteLogsButtonDisabled,
                                    action: {
                                        vm.document.text = fetchNetworkLogsAsString()
                                        vm.showFileExporter()
                                    })
            
            TextField(Constants.Settings.exportFileName, text: $vm.filename)
        }
    }
    
    @ViewBuilder
    private var UserDefaultsView: some View {
        Section {
            ProprietaryActionButton(text: Constants.Actions.clearAppUserDefaults,
                                    iconName: Constants.Image.clear,
                                    iconColor: IconColor.deletion,
                                    action: { vm.showDeleteUserDefaultsAlert() })
        } header: {
            Text(Constants.Headers.userDefaults)
        }
    }
    
    @ViewBuilder
    private var PermissionsView: some View {
        Section {
            VStack {
                ForEach(PermissionRequestType.allCases) { type in
                    PermissionItem(status: permissionsManager.statuses[type] ?? RequestPermissionStatus.notDetermined,
                                   type: type,
                                   available: permissionsManager.checkIfPermissionRequestTypeExistsInApp(type),
                                   openSystemPermissionRequest: { Task { await permissionsManager.request(type) }},
                                   openSettingsAction: { permissionsManager.openAppSettings() })
                }
            }
            
            ProprietaryActionButton(text: Constants.Actions.openAppSettings,
                                    iconName: Constants.Image.gear,
                                    iconColor: IconColor.action,
                                    action: { permissionsManager.openAppSettings() })
            .padding(.vertical, 12)

        } header: {
            Text(Constants.Headers.permissions)
        }
    }
    
    @ViewBuilder
    private var FCMPushTokenView: some View {
        Section {
            Text("\(fcmToken ?? Constants.Strings.unknownValue)")
        } header: {
            Text(Constants.Headers.fcm)
        }
    }
    
    @ViewBuilder 
    private var FirebaseView: some View {
        Section {
            Button {
                debugTool.simulateCrashExplicitly()
            } label: {
                HStack {
                    Text(Constants.Actions.simulateCrash)
                    Text(Constants.Actions.explicitCrash)
                        .font(.caption)
                    Spacer()
                    Image(systemName: Constants.Image.crash)
                }
            }
            Button {
                debugTool.simulateCrashImplicitly()
            } label: {
                HStack {
                    Text(Constants.Actions.simulateCrash)
                    Text(Constants.Actions.implicitCrash)
                        .font(.caption)
                    Spacer()
                    Image(systemName: Constants.Image.crash)
                }
            }
        } header: {
            Text(Constants.Headers.firebaseActions)
        }
    }
    
    @ViewBuilder
    private var ScreenRecordingView: some View {
        Section {
            Toggle(Constants.Actions.screenRecorderToole, isOn: .init(get: {
                if let userValue = screenRecorder.isScreenRecordingOn {
                    return userValue
                } else {
                    return screenRecorder.isScreenRecordingOnByDefault
                }
            }, set: { newValue in
                screenRecorder.isScreenRecordingOn = newValue
            }))
            
            Button(action: {
                screenRecorder.exportLastVideo()
            }, label: {
                HStack {
                    Text(Constants.Actions.screenRecorderExportLast)
                    Spacer()
                    Image(systemName: Constants.Image.export)
                }
            })
            .disabled(screenRecorder.isExportingVideo)
            
            Button(action: {
                screenRecorder.exportCurrentVideo()
            }, label: {
                HStack {
                    Text(Constants.Actions.screenRecorderExportCurrent)
                    Spacer()
                    Image(systemName: Constants.Image.export)
                }
            })
            .disabled(screenRecorder.isExportingVideo)
            
            HStack {
                Text(Constants.Actions.screenRecorderMaxVideoDuration)
                
                Picker(Constants.Actions.screenRecorderMaxVideoDuration, selection: $screenRecorder.maxVideoDuration) {
                    ForEach(Constants.MaxScreenVideoDuration.allCases) { videoDuration in
                        Text(videoDuration.ls)
                            .tag(videoDuration)
                    }
                }
                .pickerStyle(.segmented)
            }
        } header: {
            Text(Constants.Headers.screenRecording)
        }
    }
    
    @ViewBuilder
    private var SettingsView: some View {
        Section {
            VStack {
                Toggle(Constants.Strings.tracking, isOn: $networkLogger.didStart)
                    .disabled(true)
                
                if networkLogger.didStart == false {
                    Text(Constants.Strings.trackingInfo)
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                }
            }
            
            Toggle(Constants.Settings.dynamicData, isOn: $networkLogger.isDynamicDataModeOn)
            
            Toggle(Constants.Settings.educationalMode, isOn: $networkLogger.isEducationalaModeOn)

            Picker(Constants.Settings.logLimit, selection: $networkLogger.networkLogsLimit) {
                ForEach(Constants.Defaults.defaultNumberOfLogs, id: \.self) {
                    Text("\($0)")
                }
            }

            HStack {
                Text(Constants.Settings.sortingOrder)
                Picker(Constants.Settings.sortingOrder, selection: $networkLogger.sortingOrder) {
                    ForEach(Constants.SortingOrder.allCases) { sortingOrder in
                        Text(sortingOrder.rawValue)
                            .tag(sortingOrder)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Toggle(Constants.Settings.darkMode, isOn: $isDarkModeOn)
        } header: {
            Text(Constants.Headers.settings)
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
