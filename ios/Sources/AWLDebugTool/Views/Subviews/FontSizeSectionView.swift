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
            Menu(content: {
                Picker("", selection: $preferredFontSize) {
                    ForEach(DebugView.AppFontSize.allCases, id: \.self) { size in
                        Text(size.ls).tag(size)
                    }
                }
            }, label: {
                HStack {
                    Text(LS.Settings.fontSize)

                    Spacer()

                    Text(preferredFontSize.ls)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
            })
            Button {
                isShowingInfo = true
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                    Text(LS.Settings.fontSizeInfoButton)
                }
            }
            .alert(LS.Settings.fontSizeInfoButton, isPresented: $isShowingInfo) {
                Button(LS.Actions.openAppSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(LS.Headers.btnClose, role: .cancel) {}
            } message: {
                Text(LS.Settings.fontSizeInfoMessage)
            }
        } header: {
            Spacer()
                .frame(height: 0)
        }
    }
}
