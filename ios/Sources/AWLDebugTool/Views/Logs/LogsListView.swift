//
//  LogsListView.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 07.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import SwiftUI

public struct LogsListView: View {
    @Environment(\.dismiss)
    var dismiss

    @StateObject private var viewModel = LogsListViewModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogsOptions
            LogsList
        }
        .overlay {
            EmptyLogsList
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(LS.Strings.logs)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.exportNetworkLogs()
                } label: {
                    Image.with(icon: .export)
                }
                .disabled(viewModel.isDeleteLogsButtonDisabled)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if AWLDebugTool.isOpen {
                        AWLDebugTool.close()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text(LS.Headers.btnClose)
                }
            }
        }
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
        if viewModel.filteredLogs.isEmpty {
            Text(LS.Strings.emptyListOfLogs)
        }
    }

    @ViewBuilder var LogsOptions: some View {
        HStack(alignment: .center) {
            NumberOfRequestsText
            Spacer()
            SortingOrderToggleButton
            FilterLogsButton
            RemoveAllLogsButton
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .sheet(isPresented: $viewModel.isFilterActive) {
            FilterView(isFilterActive: $viewModel.isFilterActive)
        }
    }

    @ViewBuilder var NumberOfRequestsText: some View {
        Group {
            Text(LS.Strings.numberOfLogs) +
            Text("\(viewModel.filteredLogs.count) / \(viewModel.networkLogsLimit)")
                .bold()
        }
        .font(.system(size: 12))
    }

    @ViewBuilder var FilterLogsButton: some View {
        Button {
            viewModel.isFilterActive = true
        } label: {
            Image.with(icon: viewModel.isFilterChangedByUser ? .filtersSet : .filtersUnset)
        }
        .padding(4)
    }

    @ViewBuilder var SortingOrderToggleButton: some View {
        Button {
            viewModel.toggleSortingOrder()
        } label: {
            Image.with(icon: viewModel.sortingOrderIcon)
        }
        .padding(4)
        .disabled(viewModel.isSortingOrderButtonDisabled)
    }

    @ViewBuilder var RemoveAllLogsButton: some View {
        Button {
            viewModel.isShowingDeleteNetworkLogs.toggle()
        } label: {
            Image.with(icon: .clear)
                .foregroundColor(.red)
                .opacity(viewModel.isDeleteLogsButtonDisabled ? Constants.Values.disabledBtnOpacity : Constants.Values.enabledBtnOpacity)
        }
        .padding(4)
        .disabled(viewModel.isDeleteLogsButtonDisabled)
        .destructiveAlertViewModifier(isShowingAlert: $viewModel.isShowingDeleteNetworkLogs,
                                      title: LS.Alert.deleteNLTitle,
                                      message: LS.Alert.deleteNLMessage,
                                      action: { viewModel.deleteNetworkLogs() })
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
        .padding(.leading, -4)
        .padding(.trailing, 16)
    }

    @ViewBuilder
    private func LogDate(date: Date) -> some View {
        let datePart = DatesWorker.extractDate(date)
        let timePart = DatesWorker.extractTime(date)

        HStack(spacing: 6) {
            Text(datePart)
                .foregroundColor(.secondary)
            Text(timePart)
                .foregroundColor(.logTimeColor)
        }
        .font(.caption2)
    }

    @ViewBuilder
    private func LogUrl(url: String) -> some View {
        HStack {
            Text(url)
        }
        .font(.callout)
        .foregroundColor(.primary)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func LogInfo(method: String, statusCode: Int, duration: Int) -> some View {
        HStack {
            Text(method)
            Text("\(statusCode)")
            Text("(\(duration)ms)")
            if duration > viewModel.slowRequestThresholdMs {
                Text(LS.Network.slow)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .background(Capsule().stroke())
            }
        }
        .font(.callout)
        .foregroundColor(viewModel.colorFor(statusCode: statusCode))
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LogsListView()
        }
    }
}
