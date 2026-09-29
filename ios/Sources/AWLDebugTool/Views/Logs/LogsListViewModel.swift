//
//  LogsListViewModel.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 07.07.2026.
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
        return "NL\(df.string(from: date)).txt"
    }()

    private let networkLogger: NetworkLogger

    init(networkLogger: NetworkLogger = AWLDebugTool.shared.networkLogger) {
        self.networkLogger = networkLogger
    }

    var filteredLogs: [NetworkLog] {
        let searched = searchText.isEmpty ? networkLogger.networkTraffic : networkLogger.networkTraffic.filter {
            $0.method.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
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

    var networkLogsLimit: Int {
        networkLogger.networkLogsLimit
    }

    var isSortingOrderButtonDisabled: Bool {
        networkLogger.networkTraffic.count < 2
    }

    var sortingOrderIcon: Image.AppIcon {
        networkLogger.sortingOrder == .ascending ? .sortAscending : .sortDescending
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
        case 200...299: return .green
        case 300...399: return .blue
        case 400...499: return .orange
        case 500...599: return .red
        default: return .purple
        }
    }

    private func fetchNetworkLogsAsString() -> String {
        let df = DateFormatter()
        df.dateFormat = Constants.Date.dateFormatSecondary

        return networkLogger.networkTraffic
            .map { "\(df.string(from: $0.date)) \($0.method) (\($0.statusCode)) \($0.duration)ms - \($0.url)" }
            .joined(separator: "\n")
    }
}
