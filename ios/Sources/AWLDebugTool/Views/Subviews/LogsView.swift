//
//  LogsView.swift
//
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct LogsView: View {
    @ObservedObject var networkLogger: NetworkLogger

    var body: some View {
        Section {
            ShowNetworkLogsOption

            SettingsView
        } header: {
            Text(LS.Headers.logs)
        }
    }

    @ViewBuilder
    private var ShowNetworkLogsOption: some View {
        NavigationLink {
            LogsListView()
        } label: {
            Text(LS.Actions.showNetworkLogs)
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

    }
}

#Preview {
    LogsView(networkLogger: .init())
}
