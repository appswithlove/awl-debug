//
//  ColorSchemeSectionView.swift
//  AWLDebugTool
//

import SwiftUI

struct ColorSchemeSectionView: View {
    @Binding var preferredColorScheme: DebugView.AppColorScheme

    var body: some View {
        Section {
            Picker(LS.Settings.colorScheme, selection: $preferredColorScheme) {
                ForEach(DebugView.AppColorScheme.allCases, id: \.self) { scheme in
                    Text(scheme.ls).tag(scheme)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text(LS.Settings.colorScheme)
        }
    }
}
