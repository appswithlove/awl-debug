//
//  LogsListView.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 07.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import SwiftUI

/// Network module page: captured requests with search, sorting, filters, export and the log limit.
public struct LogsListView: View {
    @StateObject private var viewModel = LogsListViewModel()
    @ObservedObject private var networkLogger = AWLDebugTool.shared.networkLogger

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogsOptions
            LogsList
        }
        .overlay {
            EmptyLogsList
        }
        .panelPage(LS.Strings.logs) {
            ActionsMenu
        }
        .sheet(isPresented: $viewModel.isFilterActive) {
            FilterView(isFilterActive: $viewModel.isFilterActive)
        }
        .destructiveAlertViewModifier(isShowingAlert: $viewModel.isShowingDeleteNetworkLogs,
                                      title: LS.Alert.deleteNLTitle,
                                      message: LS.Alert.deleteNLMessage,
                                      action: { viewModel.deleteNetworkLogs() })
        .fileExporter(isPresented: $viewModel.isShowingFileExporter,
                      document: viewModel.document,
                      contentType: .plainText,
                      defaultFilename: viewModel.filename
        ) { result in
            switch result {
            case .success(let file):
                print("\(LS.logWatermark) \(file)")
            case .failure(let error):
                print("\(LS.logWatermark) \(error)")
            }
        }
    }

    @ViewBuilder var EmptyLogsList: some View {
        if !networkLogger.didStart {
            Text(LS.Strings.trackingInfo)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        } else if viewModel.filteredLogs.isEmpty {
            Text(LS.Strings.emptyListOfLogs)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder var ActionsMenu: some View {
        Menu {
            Button(action: viewModel.exportNetworkLogs) {
                Label(LS.Actions.exportNetworkLogs, systemImage: Image.AppIcon.export.rawValue)
            }
            .disabled(viewModel.filteredLogs.isEmpty)
            Picker(LS.Settings.logLimit, selection: $networkLogger.networkLogsLimit) {
                ForEach(Constants.Defaults.defaultNumberOfLogs, id: \.self) {
                    Text(verbatim: "\($0)")
                }
            }
            .pickerStyle(.menu)
            Button(role: .destructive) {
                viewModel.isShowingDeleteNetworkLogs = true
            } label: {
                Label(LS.Actions.clearNetworkLogs, systemImage: Image.AppIcon.clear.rawValue)
            }
            .disabled(viewModel.isDeleteLogsButtonDisabled)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder var LogsOptions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center) {
                NumberOfRequestsText
                Spacer()
                SortingOrderToggleButton
                FilterLogsButton
            }
            VStack(alignment: .leading, spacing: 4) {
                NumberOfRequestsText
                HStack {
                    SortingOrderToggleButton
                    FilterLogsButton
                }
            }
        }
        .font(.footnote)
        .buttonStyle(.borderless)
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
    }

    @ViewBuilder var NumberOfRequestsText: some View {
        Text(LS.Strings.numberOfLogs) +
        Text(verbatim: "\(viewModel.filteredLogs.count) / \(viewModel.networkLogsLimit)")
            .bold()
    }

    @ViewBuilder var FilterLogsButton: some View {
        Button {
            viewModel.isFilterActive = true
        } label: {
            Label(LS.Strings.filters, systemImage: (viewModel.isFilterChangedByUser ? Image.AppIcon.filtersSet : .filtersUnset).rawValue)
        }
        .padding(4)
    }

    @ViewBuilder var SortingOrderToggleButton: some View {
        Button {
            viewModel.toggleSortingOrder()
        } label: {
            Label(viewModel.sortingOrderTitle, systemImage: viewModel.sortingOrderIcon.rawValue)
        }
        .padding(4)
        .disabled(viewModel.isSortingOrderButtonDisabled)
    }

    @ViewBuilder var LogsList: some View {
        List(viewModel.filteredLogs) { log in
            NavigationLink {
                LogDetailView(log: log)
            } label: {
                VStack(alignment: .leading) {
                    LogDate(date: log.date)
                    LogUrl(url: log.url)
                    LogInfo(method: log.method, statusCode: log.statusCode, duration: log.duration)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: LS.Strings.searchLogs)
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
    }

    @ViewBuilder
    private func LogDate(date: Date) -> some View {
        let datePart = DatesWorker.extractDate(date)
        let timePart = DatesWorker.extractTime(date)

        HStack(spacing: 6) {
            Text(datePart)
                .foregroundStyle(.secondary)
            Text(timePart)
                .foregroundStyle(Color.logTimeColor)
        }
        .font(.caption2)
    }

    @ViewBuilder
    private func LogUrl(url: String) -> some View {
        Text(url)
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private func LogInfo(method: String, statusCode: Int, duration: Int) -> some View {
        HStack {
            Text(method)
            Text(verbatim: "\(statusCode)")
            Text(verbatim: "(\(duration)ms)")
            if duration > viewModel.slowRequestThresholdMs {
                Text(LS.Network.slow)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .background(Capsule().stroke())
            }
        }
        .font(.callout)
        .foregroundStyle(viewModel.colorFor(statusCode: statusCode))
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LogsListView()
        }
    }
}
