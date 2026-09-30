//
//  UserDefaultsView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

/// Clear App Data: pick what to delete, confirm, then close the app to start fresh.
struct UserDefaultsView: View {
    let appGroupIdentifiers: [String]

    @State private var selection = AppDataCleaner.Area.defaultSelection
    @State private var isConfirming = false
    @State private var isCleared = false

    var body: some View {
        Form {
            Section {
                ForEach(AppDataCleaner.Area.allCases) { area in
                    Button {
                        toggle(area)
                    } label: {
                        HStack {
                            Text(area.title)
                                .foregroundStyle(Color(UIColor.label))
                            Spacer()
                            if selection.contains(area) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .accessibilityAddTraits(selection.contains(area) ? .isSelected : [])
                }
            }

            Section {
                if isCleared {
                    Text(LS.ClearData.done)
                        .font(.footnote)
                    Button(LS.ClearData.closeApp, role: .destructive) {
                        exit(0)
                    }
                } else {
                    ProprietaryActionButton(text: LS.ClearData.button,
                                            icon: .clear,
                                            iconColor: IconColor.deletion,
                                            action: { isConfirming = true })
                        .disabled(selection.isEmpty)
                }
            }
        }
        .panelPage(LS.ClearData.title)
        .alert(LS.ClearData.confirmTitle, isPresented: $isConfirming) {
            Button(LS.Alert.btnCancel, role: .cancel) {}
            Button(LS.ClearData.confirm, role: .destructive, action: clear)
        } message: {
            Text(LS.ClearData.confirmMessage)
        }
    }

    private func toggle(_ area: AppDataCleaner.Area) {
        if selection.contains(area) {
            selection.remove(area)
        } else {
            selection.insert(area)
        }
    }

    private func clear() {
        AppDataCleaner(appGroupIdentifiers: appGroupIdentifiers).clear(selection)
        isCleared = true
    }
}
