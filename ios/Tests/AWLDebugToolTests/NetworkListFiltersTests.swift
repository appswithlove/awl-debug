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
}
