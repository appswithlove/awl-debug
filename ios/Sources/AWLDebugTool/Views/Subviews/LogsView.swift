//
//  LogsView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct LogsView: View {
    @ObservedObject var networkLogger: NetworkLogger
    let isDeleteLogsButtonDisabled: Bool
    let showDeleteNetworkLogsAlert: () -> Void
    let isShowingDeleteNetworkLogs: Binding<Bool>
    let deleteNetworkLogs: () -> Void
    let isShowingDeleteUserDefaults: Binding<Bool>
    let dismiss: () -> Void
    let filename: Binding<String>
    let fetchNetworkLogsAsString: () -> String
    let showFileExporter: (String) -> Void
    
    var body: some View {
        Section {
            ShowNetworkLogsOption
            
            ProprietaryActionButton(text: LS.Actions.clearNetworkLogs,
                                    icon: .clear,
                                    iconColor: IconColor.deletion,
                                    isDisabled: isDeleteLogsButtonDisabled,
                                    action: { showDeleteNetworkLogsAlert() })
            
            ExportNetworkLogsOption
            
            SettingsView
        } header: {
            Text(LS.Headers.logs)
        }
        .destructiveAlertViewModifier(isShowingAlert: isShowingDeleteNetworkLogs,
                                      title: LS.Alert.deleteNLTitle,
                                      message: LS.Alert.deleteNLMessage,
                                      action: { deleteNetworkLogs() })
        .textCase(nil)
    }
    
    @ViewBuilder
    private var ShowNetworkLogsOption: some View {
        NavigationLink {
            LogsListView(onClose: { dismiss() })
        } label: {
            Text(LS.Actions.showNetworkLogs)
        }
    }
    
    @ViewBuilder
    private var ExportNetworkLogsOption: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProprietaryActionButton(
                text: LS.Actions.exportNetworkLogs,
                icon: .export,
                iconColor: IconColor.action,
                isDisabled: isDeleteLogsButtonDisabled,
                action: {
                    let logs = fetchNetworkLogsAsString()
                    showFileExporter(logs)
                }
            )

            TextField(LS.Settings.exportFileName, text: filename)
        }
    }
    
    @ViewBuilder
    private var SettingsView: some View {
        VStack {
            Toggle(LS.Strings.tracking, isOn: $networkLogger.didStart)
                .disabled(true)
            
            if networkLogger.didStart == false {
                Text(LS.Strings.trackingInfo)
                    .font(.footnote)
                    .foregroundColor(.accentColor)
            }
        }
        
        Toggle(LS.Settings.dynamicData, isOn: $networkLogger.isDynamicDataModeOn)
        
        Picker(LS.Settings.logLimit, selection: $networkLogger.networkLogsLimit) {
            ForEach(Constants.Defaults.defaultNumberOfLogs, id: \.self) {
                Text("\($0)")
            }
        }

        HStack {
            Text(LS.Settings.sortingOrder)
            Picker(LS.Settings.sortingOrder, selection: $networkLogger.sortingOrder) {
                ForEach(Constants.SortingOrder.allCases) { sortingOrder in
                    Text(sortingOrder.rawValue)
                        .tag(sortingOrder)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview {
    LogsView(
        networkLogger: .init(),
        isDeleteLogsButtonDisabled: false,
        showDeleteNetworkLogsAlert: {},
        isShowingDeleteNetworkLogs: .constant(false),
        deleteNetworkLogs: {},
        isShowingDeleteUserDefaults: .constant(false),
        dismiss: {},
        filename: .constant("Test.txt"),
        fetchNetworkLogsAsString: { () in "Test"},
        showFileExporter: { _ in })
}
