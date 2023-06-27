//
//  DebugView.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 07.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import SwiftUI

public struct DebugView: View {
    @StateObject private var networkLogsService = NetworkLogsService.shared
    @Environment(\.dismiss) var dismiss
    
    private var fcmToken: String = "unknown token"
    
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
            .navigationTitle("Debug Tool")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        networkLogsService.saveSettings()
                        networkLogsService.areSettingsChanged = true
                    } label: {
                        Text("Save and exit")
                    }
                }
            }
        }
        .onAppear(perform: networkLogsService.refreshData)
        .alert(Constants.Alert.alertTitle, isPresented: $networkLogsService.areSettingsChanged) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(Constants.Alert.alertMessage)
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
            NavigationLink {
                LogsView()
            } label: {
                Text("Show network logs")
            }
            Button {
                networkLogsService.deleteNetworkLogs()
            } label: {
                HStack {
                    Text("Clear network logs")
                    Spacer()
                    Image(systemName: "trash")
                }
            }
            Button {
                networkLogsService.exportNetworkLogs()
            } label: {
                HStack {
                    Text("Export network logs")
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                }
            }
        } header: {
            Text("Logs")
        }
    }
    
    @ViewBuilder private func FCMPushTokenView() -> some View {
        Section {
            Text("\(fcmToken)")
        } header: {
            Text("FCM push token")
        }
    }
    
    @ViewBuilder private func FirebaseView() -> some View {
        Section {
            Button {
                networkLogsService.doTestCrash1()
            } label: {
                HStack {
                    Text("Simulate crash")
                    Text("- explicit fatal error")
                        .font(.caption)
                    Spacer()
                    Image(systemName: "pip.remove")
                }
            }
            Button {
                networkLogsService.doTestCrash2()
            } label: {
                HStack {
                    Text("Simulate crash")
                    Text("- implicit fatal error")
                        .font(.caption)
                    Spacer()
                    Image(systemName: "pip.remove")
                }
            }
        } header: {
            Text("Firebase actions")
        }
    }
    
    @ViewBuilder private func SettingsView() -> some View {
        Section {
            Picker("Number of logs per session", selection: $networkLogsService.standardLogLimit) {
                ForEach(Constants.Values.numberOfLogs, id: \.self) {
                    Text("\($0)")
                }
            }
            .disabled(networkLogsService.useCustomLogLimit)
            Toggle("Custom number of network logs", isOn: $networkLogsService.useCustomLogLimit)
            if networkLogsService.useCustomLogLimit {
                TextField("750", value: $networkLogsService.customLogLimit, format: .number)
                    .keyboardType(.numberPad)
            }
            Toggle("Custom file name for network logs", isOn: $networkLogsService.useCustomFileName)
            if networkLogsService.useCustomFileName {
                TextField("NetworkLogs", text: $networkLogsService.customFileName)
            }
        } header: {
            Text("Settings")
        }
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView(fcmToken: "qwert1234")
    }
}
