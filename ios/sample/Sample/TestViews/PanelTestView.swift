//
//  PanelTestView.swift
//  Sample
//

#if AWL_DEBUG
import AWLDebugTool
#endif
import SwiftUI

/// Opens the panel over the app's own sheets and full-screen covers.
struct PanelTestView: View {
    @State private var isShowingSheet = false
    @State private var isShowingCover = false
#if AWL_DEBUG
    @State private var isActivated = AWLDebugTool.isActivated
    @State private var isDemoSectionShown = DemoSection.isShown
#endif

    var body: some View {
        VStack(spacing: 16) {
            OpenPanelButton()
            Button("Show sheet") { isShowingSheet = true }
            Button("Show full-screen cover") { isShowingCover = true }
#if AWL_DEBUG
            Toggle("Gestures open the panel", isOn: $isActivated)
                .onChange(of: isActivated) { AWLDebugTool.isActivated = $0 }
                .padding(.horizontal)
            Toggle("Demo section in the panel", isOn: $isDemoSectionShown)
                .onChange(of: isDemoSectionShown) { DemoSection.setShown($0) }
                .padding(.horizontal)
#endif
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $isShowingSheet) {
            ModalContent(title: "Sheet") { isShowingSheet = false }
        }
        .fullScreenCover(isPresented: $isShowingCover) {
            ModalContent(title: "Full-screen cover") { isShowingCover = false }
        }
    }
}

private struct ModalContent: View {
    let title: String
    let close: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title).font(.title)
            OpenPanelButton()
            Button("Close \(title.lowercased())", action: close)
        }
        .buttonStyle(.bordered)
    }
}

#if AWL_DEBUG
/// A section on the panel's start page, added through `AWLDebugExtensions` the way a separate package would.
@MainActor
private enum DemoSection {
    private static let section = AWLDebugExtensionSection(id: "demo", order: 30)
    private static var registration: AWLDebugRegistration?
    private static var taps = 0
    private static var isSwitchOn = false

    static var isShown: Bool {
        registration != nil
    }

    static func setShown(_ isShown: Bool) {
        if isShown, registration == nil {
            update()
            registration = AWLDebugExtensions.register(section)
        } else if !isShown {
            registration?.cancel()
            registration = nil
        }
    }

    private static func update() {
        section.items = [
            .title("Demo section", action: AWLDebugExtensionAction("Tap") {
                taps += 1
                update()
            }),
            .text("Tapped \(taps) times"),
            .text("Demo ID: demo-1234", style: .monospace, copyValue: "demo-1234"),
            .toggle("Demo switch", isOn: isSwitchOn) { isOn in
                isSwitchOn = isOn
                update()
            },
            .link("Open demo", badge: "Closes the panel first") {
                AWLDebugTool.log("Demo link opened", tag: "Demo")
            },
        ]
    }
}
#endif

private struct OpenPanelButton: View {
    var body: some View {
        Button("Open debug panel") {
#if AWL_DEBUG
            AWLDebugTool.open()
#endif
        }
    }
}
