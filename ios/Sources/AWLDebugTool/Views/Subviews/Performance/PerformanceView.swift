import SwiftUI

/// Performance module page: the "Measure performance" and overlay switches, and the values while the monitors
/// run (measuring or overlay visible).
struct PerformanceView: View {
    @ObservedObject var performance: PerformanceController
    @Binding var isOverlayVisible: Bool
    let debugTool: AWLDebugTool

    var body: some View {
        Form {
            Section {
                Toggle(LS.Performance.measure, isOn: $performance.isMeasuring)
                Toggle(LS.Performance.showPerformanceOverlay, isOn: $isOverlayVisible)
                    .onChange(of: isOverlayVisible) { _ in
                        performance.updateSampling()
                    }
            }

            if performance.isMeasuring || isOverlayVisible {
                // Same order as the spec and Android: CPU, RAM, Battery, UI freeze.
                Section {
                    CPUView(cpuMonitor: debugTool.cpuMonitor)
                }
                Section {
                    RAMView(ramMonitor: debugTool.ramMonitor)
                }
                Section {
                    BatteryView(monitor: debugTool.batteryMonitor)
                }
                Section {
                    MainThreadView(monitor: debugTool.mainThreadMonitor)
                }
            }
        }
        .panelPage(LS.Performance.performanceSectionTitle)
    }
}
