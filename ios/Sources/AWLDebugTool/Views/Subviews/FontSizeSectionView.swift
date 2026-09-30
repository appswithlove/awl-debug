//
//  FontSizeSectionView.swift
//  AWLDebugTool
//

import SwiftUI

struct FontSizeSectionView: View {
    @Binding var preferredFontSize: DebugView.AppFontSize
    @State private var isShowingInfo = false

    var body: some View {
        Section {
            Picker(LS.Settings.fontSize, selection: $preferredFontSize) {
                ForEach(DebugView.AppFontSize.allCases, id: \.self) { size in
                    Text(size.ls).tag(size)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text(LS.Settings.fontSize)
        }

        Section {
            Button {
                isShowingInfo = true
            } label: {
                Label(LS.Settings.fontSizeInfoButton, systemImage: "info.circle")
            }
            .alert(LS.Settings.fontSizeInfoButton, isPresented: $isShowingInfo) {
                Button(LS.Settings.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(LS.Headers.btnClose, role: .cancel) {}
            } message: {
                Text(LS.Settings.fontSizeInfoMessage)
            }
        }
    }
}
