//
//  LogsView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct LogsView: View {
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
            
            ProprietaryActionButton(text: Constants.Actions.clearNetworkLogs,
                                    iconName: Constants.Image.clear,
                                    iconColor: IconColor.deletion,
                                    isDisabled: isDeleteLogsButtonDisabled,
                                    action: { showDeleteNetworkLogsAlert() })
            
            ExportNetworkLogsOption
        } header: {
            Text(Constants.Headers.logs)
        }
        .destructiveAlertViewModifier(isShowingAlert: isShowingDeleteNetworkLogs,
                                      title: Constants.Alert.deleteNLTitle,
                                      message: Constants.Alert.deleteNLMessage,
                                      action: { deleteNetworkLogs() })
        .textCase(nil)
    }
    
    @ViewBuilder
    private var ShowNetworkLogsOption: some View {
        NavigationLink {
            LogsListView(onClose: { dismiss() })
        } label: {
            Text(Constants.Actions.showNetworkLogs)
        }
    }
    
    @ViewBuilder
    private var ExportNetworkLogsOption: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProprietaryActionButton(
                text: Constants.Actions.exportNetworkLogs,
                iconName: Constants.Image.export,
                iconColor: IconColor.action,
                isDisabled: isDeleteLogsButtonDisabled,
                action: {
                    let logs = fetchNetworkLogsAsString()
                    showFileExporter(logs)
                }
            )

            TextField(Constants.Settings.exportFileName, text: filename)
        }
    }
}

#Preview {
    LogsView(isDeleteLogsButtonDisabled: false,
             showDeleteNetworkLogsAlert: {},
             isShowingDeleteNetworkLogs: .constant(false),
             deleteNetworkLogs: {},
             isShowingDeleteUserDefaults: .constant(false),
             dismiss: {},
             filename: .constant("Test.txt"),
             fetchNetworkLogsAsString: { () in "Test"},
             showFileExporter: { _ in })
}
