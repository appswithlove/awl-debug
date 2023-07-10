//
//  DebugView.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 07.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import SwiftUI

public struct DebugView: View {
    @StateObject private var networkLogsService = AWLDebugTool.shared
    @Environment(\.dismiss) var dismiss
    
    private var fcmToken: String = Constants.Strings.unknownValue
    
    public init(fcmToken: String) {
        self.fcmToken = fcmToken
    }
    
    public var body: some View {
        NavigationView {
            Form {
                LogOptionsView()
                FirebaseView()
                FCMPushTokenView()
                SettingsView()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(Constants.Strings.appName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        networkLogsService.saveSettings()
                        networkLogsService.areSettingsChanged = true
                    } label: {
                        Text(Constants.Toolbar.saveAndExit)
                    }
                }
            }
        }
        .onAppear(perform: networkLogsService.refreshData)
        .alert(Constants.Alert.saveSettingsTitle, isPresented: $networkLogsService.areSettingsChanged) {
            Button(Constants.Alert.btnOK) {
                dismiss()
            }
        } message: {
            Text(Constants.Alert.saveSettingsMessage)
        }
        .fileExporter(isPresented: $networkLogsService.isShowingFileExporter, document: networkLogsService.document, contentType: .plainText, defaultFilename: networkLogsService.filename) { result in
            switch result {
            case .success(let file):
                print(file)
            case .failure(let error):
                print(error)
            }
        }
        .environmentObject(networkLogsService)
    }
    
    @ViewBuilder private func LogOptionsView() -> some View {
        Section {
            StatusBar()
            NavigationLink {
                LogsView()
            } label: {
                Text(Constants.Actions.showNetworkLogs)
            }
            Button {
                networkLogsService.isShowingDeleteNetworkLogs = true
            } label: {
                HStack {
                    Text(Constants.Actions.clearNetworkLogs)
                    Spacer()
                    Image(systemName: Constants.Image.clear)
                }
            }
            Button {
                networkLogsService.exportNetworkLogs()
            } label: {
                HStack {
                    Text(Constants.Actions.exportNetworkLogs)
                    Spacer()
                    Image(systemName: Constants.Image.export)
                }
            }
        } header: {
            Text(Constants.Headers.logs)
        }
        .alert(Constants.Alert.deleteNLTitle, isPresented: $networkLogsService.isShowingDeleteNetworkLogs) {
            Button(Constants.Alert.btnCancel, role: .cancel) {}
            Button(Constants.Alert.btnDelete, role: .destructive) {
                networkLogsService.deleteNetworkLogs()
            }
        } message: {
            Text(Constants.Alert.deleteNLMessage)
        }
        .textCase(nil)
    }
    
    @ViewBuilder private func FCMPushTokenView() -> some View {
        Section {
            Text("\(fcmToken)")
        } header: {
            Text(Constants.Headers.fcm)
        }
    }
    
    @ViewBuilder private func FirebaseView() -> some View {
        Section {
            Button {
                networkLogsService.simulateCrashExplicitly()
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
                networkLogsService.simulateCrashImplicitly()
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
    
    @ViewBuilder private func SettingsView() -> some View {
        Section {
            Toggle(Constants.Strings.tracking, isOn: $networkLogsService.trackNetworkLogs)
            Picker(Constants.Settings.standardLogLimit, selection: $networkLogsService.standardLogLimit) {
                ForEach(Constants.Defaults.defaultNumberOfLogs, id: \.self) {
                    Text("\($0)")
                }
            }
            .disabled(networkLogsService.useCustomLogLimit)
            Toggle(Constants.Settings.customLogLimit, isOn: $networkLogsService.useCustomLogLimit)
            if networkLogsService.useCustomLogLimit {
                TextField("\(Constants.Defaults.defaultLogLimit)", value: $networkLogsService.customLogLimit, format: .number)
                    .keyboardType(.numberPad)
            }
            Toggle(Constants.Settings.customFileName, isOn: $networkLogsService.useCustomFileName)
            if networkLogsService.useCustomFileName {
                TextField(Constants.Defaults.defaultFilename, text: $networkLogsService.customFileName)
            }
        } header: {
            Text(Constants.Headers.settings)
        }
    }

    @ViewBuilder private func StatusBar() -> some View {
        Label {
            Text(networkLogsService.isTrackingNetworkLogs ? Constants.Strings.stopTracking : Constants.Strings.startTracking)
                .foregroundColor(.secondary)
        } icon: {
            Button {
                networkLogsService.isTrackingNetworkLogs.toggle()
            } label: {
                Image(systemName:networkLogsService.isTrackingNetworkLogs ? Constants.Image.pause : Constants.Image.play)
                    .foregroundColor(networkLogsService.isTrackingNetworkLogs ? .red : .green)
            }
        }
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView(fcmToken: Constants.Strings.testFcmToken)
    }
}
