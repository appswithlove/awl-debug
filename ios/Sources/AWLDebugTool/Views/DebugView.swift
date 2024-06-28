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
    
    @Environment(\.dismiss) var dismiss
    
    private var fcmToken: String?
    
    @State private var isShowingDeleteNetworkLogs = false
    @State private var isShowingFileExporter = false
    
    @State private var document = TextDocument(text: "")
    @State private var filename: String = {
        let date = Date.now
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        return "NL\(df.string(from: date)).txt"
    }()
    
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
    
    public init(fcmToken: String?) {
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
                        dismiss()
                    } label: {
                        Text(Constants.Headers.btnClose)
                    }
                }
            }
        }
        .fileExporter(isPresented: $isShowingFileExporter, document: document, contentType: .plainText, defaultFilename: filename) { result in
            switch result {
            case .success(let file):
                print(file)
            case .failure(let error):
                print(error)
            }
        }
    }
    
    @ViewBuilder private func LogOptionsView() -> some View {
        Section {
            NavigationLink {
                LogsView(onClose: { dismiss() })
            } label: {
                Text(Constants.Actions.showNetworkLogs)
            }
            Button {
                isShowingDeleteNetworkLogs = true
            } label: {
                HStack {
                    Text(Constants.Actions.clearNetworkLogs)
                    Spacer()
                    Image(systemName: Constants.Image.clear)
                        .foregroundColor(.red)
                        .opacity(isDeleteLogsButtonDisabled ? Constants.Values.disabledBtnOpacity : Constants.Values.enabledBtnOpacity)
                }
            }
            .disabled(isDeleteLogsButtonDisabled)
            
            VStack {
                Button {
                    document.text = fetchNetworkLogsAsString()
                    self.isShowingFileExporter = true
                } label: {
                    HStack {
                        Text(Constants.Actions.exportNetworkLogs)
                        Spacer()
                        Image(systemName: Constants.Image.export)
                    }
                }
                
                TextField(Constants.Settings.exportFileName, text: $filename)
            }
        } header: {
            Text(Constants.Headers.logs)
        }
        .alert(Constants.Alert.deleteNLTitle, isPresented: $isShowingDeleteNetworkLogs) {
            Button(Constants.Alert.btnCancel, role: .cancel) {}
            Button(Constants.Alert.btnDelete, role: .destructive) {
                networkLogger.deleteNetworkLogs()
            }
        } message: {
            Text(Constants.Alert.deleteNLMessage)
        }
        .textCase(nil)
    }
    
    @ViewBuilder private func FCMPushTokenView() -> some View {
        Section {
            Text("\(fcmToken ?? Constants.Strings.unknownValue)")
        } header: {
            Text(Constants.Headers.fcm)
        }
    }
    
    @ViewBuilder private func FirebaseView() -> some View {
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
    
    @ViewBuilder private func SettingsView() -> some View {
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

        } header: {
            Text(Constants.Headers.settings)
        }
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView(fcmToken: "qwert1234")
    }
}
