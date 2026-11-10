//
//  LogsListViewModel.swift
//  AWLDebugTool
//

import SwiftUI

@MainActor
final class LogsListViewModel: ObservableObject {
    @Published var searchText = LS.Strings.emptyString
    @Published var isFilterActive = false
    @Published var isShowingDeleteNetworkLogs = false
    @Published var isShowingFileExporter = false
    @Published var document = TextDocument(text: "")
    @Published var filename: String = {
        let date = Date.now
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        return "awl-debug-network-\(df.string(from: date)).txt"
    }()

    private let networkLogger: NetworkLogger

    init(networkLogger: NetworkLogger = AWLDebugTool.shared.networkLogger) {
        self.networkLogger = networkLogger
    }

    private var searchedLogs: [NetworkLog] {
        searchText.isEmpty ? networkLogger.networkTraffic : networkLogger.networkTraffic.filter {
            $0.method.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText) ||
            "\($0.statusCode)".contains(searchText)
        }
    }

    /// Filters only hide what the user turned off; a method, status or host without a filter, such as status 0 of a failed request, stays visible.
    var filteredLogs: [NetworkLog] {
        // Each of these walks the whole traffic, so it is read once and not per log.
        let methods = networkLogger.methods
        let codes = networkLogger.codes
        let endpoints = networkLogger.endpoints
        let filteredByEndpoints = searchedLogs.filter { log in
            (methods[log.method] ?? true)
                && (codes[log.statusCode] ?? true)
                && (NetworkLogger.endpoint(of: log.url).flatMap { endpoints[$0] } ?? true)
        }

        return filteredByEndpoints.sorted { log1, log2 in
            switch networkLogger.sortingOrder {
            case .ascending:
                return log1.date < log2.date
            case .descending:
                return log1.date > log2.date
            }
        }
    }

    var slowRequestThresholdMs: Int {
        networkLogger.config.slowRequestThresholdMs
    }

    var networkLogsLimit: Int {
        networkLogger.networkLogsLimit
    }

    var isSortingOrderButtonDisabled: Bool {
        networkLogger.networkTraffic.count < 2
    }

    var sortingOrderIcon: Image.AppIcon {
        networkLogger.sortingOrder == .ascending ? .sortAscending : .sortDescending
    }

    var sortingOrderTitle: String {
        networkLogger.sortingOrder == .ascending ? LS.Network.oldestFirst : LS.Network.newestFirst
    }

    var isDeleteLogsButtonDisabled: Bool {
        networkLogger.networkTraffic.isEmpty
    }

    var isFilterChangedByUser: Bool {
        networkLogger.methods.values.contains(false) ||
        networkLogger.codes.values.contains(false) ||
        networkLogger.endpoints.values.contains(false)
    }

    /// Shown above the list while filters are on: "Filters hide 3 of 10 requests".
    var hiddenByFiltersText: String {
        let searched = searchedLogs.count
        return LS.Network.hiddenByFilters(hidden: searched - filteredLogs.count, total: searched)
    }

    func showAllRequests() {
        networkLogger.selectAllMethods()
        networkLogger.selectAllCodes()
        networkLogger.selectAllEndpoints()
    }

    func toggleSortingOrder() {
        networkLogger.sortingOrder = networkLogger.sortingOrder == .ascending ? .descending : .ascending
    }

    func deleteNetworkLogs() {
        networkLogger.deleteNetworkLogs()
    }

    func exportNetworkLogs() {
        document.text = fetchNetworkLogsAsString()
        isShowingFileExporter = true
    }

    func colorFor(statusCode: Int) -> Color {
        switch statusCode {
        case 200...299: return .statusPositive
        case 300...399: return .statusRedirect
        case 400...499: return .statusWarning
        case 500...599: return .statusError
        default: return .statusInfo
        }
    }

    private func fetchNetworkLogsAsString() -> String {
        filteredLogs
            .map(\.exportText)
            .joined(separator: "\n\n")
    }
}
