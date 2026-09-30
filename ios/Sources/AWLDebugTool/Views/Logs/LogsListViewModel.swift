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

    var filteredLogs: [NetworkLog] {
        let searched = searchText.isEmpty ? networkLogger.networkTraffic : networkLogger.networkTraffic.filter {
            $0.method.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText) ||
            "\($0.statusCode)".contains(searchText)
        }

        let filteredByRequestMethods = searched.filter { log in
            networkLogger.methods[log.method] ?? false
        }

        let filteredByResponseCodes = filteredByRequestMethods.filter { log in
            networkLogger.codes[log.statusCode] ?? false
        }

        let filteredByEndpoints = filteredByResponseCodes.filter { log in
            networkLogger.endpoints[networkLogger.findFirstMatch(in: log.url, with: Constants.Regex.endpointsPattern) ?? ""] ?? false
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
