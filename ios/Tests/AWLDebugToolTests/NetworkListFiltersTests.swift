import XCTest
@testable import AWLDebugTool

@MainActor
final class NetworkListFiltersTests: XCTestCase {

    private func log(_ method: String, _ statusCode: Int) -> NetworkLog {
        NetworkLog(id: UUID(), method: method, url: "https://api.example.com/v1/items", date: Date(), duration: 10, statusCode: statusCode)
    }

    func testFiltersHideRequestsUntilShowAll() {
        let logger = NetworkLogger()
        logger.appendNetworkLog(log("GET", 200))
        logger.appendNetworkLog(log("POST", 201))
        let viewModel = LogsListViewModel(networkLogger: logger)
        // Filters are stored on the device; leave them all on for other tests.
        defer { viewModel.showAllRequests() }

        logger.deselectAllMethods()

        XCTAssertTrue(viewModel.isFilterChangedByUser)
        XCTAssertTrue(viewModel.filteredLogs.isEmpty)
        XCTAssertEqual(viewModel.hiddenByFiltersText, "Filters hide 2 of 2 requests")

        viewModel.showAllRequests()

        XCTAssertFalse(viewModel.isFilterChangedByUser)
        XCTAssertEqual(viewModel.filteredLogs.count, 2)
    }

    /// A WebSocket the system loaded, as `PassThroughLogger` stores it: status 101, no request body, a placeholder response.
    private func webSocketLog() -> NetworkLog {
        var log = NetworkLog(id: UUID(), method: "GET", url: "wss://sync.example.com/sync/stream", date: Date(), duration: 60_000, statusCode: 101)
        log.requestHeaders = [.init(name: "Upgrade", value: "websocket")]
        log.responseBody = NetworkRedactor.placeholderBody(LS.Network.streamNotCaptured, contentType: nil, totalBytes: 2_048)
        log.responseBytes = 2_048
        return log
    }

    func testWebSocketsPortsAndFailedRequestsAreListed() {
        let logger = NetworkLogger()
        let webSocket = webSocketLog()
        logger.appendNetworkLog(webSocket)
        logger.appendNetworkLog(NetworkLog(id: UUID(), method: "GET", url: "http://127.0.0.1:8080/health", date: Date(), duration: 5, statusCode: 200))
        logger.appendNetworkLog(NetworkLog(id: UUID(), method: "GET", url: "https://api.example.com", date: Date(), duration: 5, statusCode: 200))
        logger.appendNetworkLog(NetworkLog(id: UUID(), method: "POST", url: "https://api.example.com/v1/items", date: Date(), duration: 5, statusCode: 0))
        let viewModel = LogsListViewModel(networkLogger: logger)
        defer { viewModel.showAllRequests() }

        XCTAssertEqual(viewModel.filteredLogs.count, 4)
        XCTAssertEqual(viewModel.hiddenByFiltersText, "Filters hide 0 of 4 requests")
        XCTAssertNotNil(logger.endpoints["wss://sync.example.com"])

        viewModel.searchText = "wss"
        XCTAssertEqual(viewModel.filteredLogs.map(\.id), [webSocket.id])
        viewModel.searchText = "101"
        XCTAssertEqual(viewModel.filteredLogs.map(\.id), [webSocket.id])
        viewModel.searchText = ""

        logger.filtersStorage.updateEndpointFilter(false, for: "wss://sync.example.com")
        XCTAssertEqual(viewModel.filteredLogs.count, 3)
    }

    func testWebSocketExportAndCurlNeedNoBody() {
        let log = webSocketLog()

        XCTAssertTrue(log.exportText.contains("GET 101 60000ms wss://sync.example.com/sync/stream"), log.exportText)
        XCTAssertTrue(log.exportText.contains("(stream, not captured)"), log.exportText)
        XCTAssertTrue(log.curlCommand.contains("'wss://sync.example.com/sync/stream'"), log.curlCommand)
        XCTAssertFalse(log.curlCommand.contains("-d"), log.curlCommand)
    }

    func testKeepsExactlyTheLimit() {
        let logger = NetworkLogger()
        let storedLimit = logger.networkLogsLimit
        defer { logger.networkLogsLimit = storedLimit }
        logger.networkLogsLimit = 2

        for statusCode in [200, 201, 202] {
            logger.appendNetworkLog(log("GET", statusCode))
        }

        XCTAssertEqual(logger.networkTraffic.map(\.statusCode), [201, 202])
    }
}
