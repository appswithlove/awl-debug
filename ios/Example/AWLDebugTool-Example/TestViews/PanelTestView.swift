//
//  PanelTestView.swift
//  AWLDebugTool-Example
//

#if DEBUG || STAGING
import AWLDebugTool
#endif
import SwiftUI

/// Opens the panel over the app's own sheets and full-screen covers.
struct PanelTestView: View {
    @State private var isShowingSheet = false
    @State private var isShowingCover = false

    var body: some View {
        VStack(spacing: 16) {
            OpenPanelButton()
            Button("Show sheet") { isShowingSheet = true }
            Button("Show full-screen cover") { isShowingCover = true }
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

private struct OpenPanelButton: View {
    var body: some View {
        Button("Open debug panel") {
#if DEBUG || STAGING
            AWLDebugTool.open()
#endif
        }
    }
}
