import Combine
import SwiftUI

struct BatteryView: View {
    @StateObject private var vm: BatteryViewModel

    init(monitor: BatteryMonitor) {
        _vm = .init(wrappedValue: BatteryViewModel(monitor: monitor))
    }

    var body: some View {
        Label(vm.title, systemImage: vm.isCharging ? "battery.100.bolt" : "battery.75")
    }
}

@MainActor
final class BatteryViewModel: ObservableObject {
    @Published var title = LS.Performance.batteryUnknown
    @Published var isCharging = false

    private var cancellables = Set<AnyCancellable>()

    init(monitor: BatteryMonitor) {
        monitor.collection.snapshotPublisher
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] snapshot in self?.apply(snapshot) }
            .store(in: &cancellables)
        if let last = monitor.collection.history.last {
            apply(last)
        }
    }

    private func apply(_ snapshot: BatteryMonitor.Snapshot) {
        title = snapshot.percent.map { "\(LS.Performance.battery): \(Int($0.rounded())) %" } ?? LS.Performance.batteryUnknown
        isCharging = snapshot.state == .charging || snapshot.state == .full
    }
}
