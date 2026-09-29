//
//  ColorSchemeSectionView.swift
//  AWLDebugTool
//

import SwiftUI

struct ColorSchemeSectionView: View {
    @Binding var preferredColorScheme: DebugView.AppColorScheme

    var body: some View {
        Section {
            Menu(content: {
                Picker("", selection: $preferredColorScheme) {
                    ForEach(DebugView.AppColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.ls).tag(scheme)
                    }
                }
            }, label: {
                HStack {
                    Text(LS.Settings.colorScheme)

                    Spacer()

                    Text(preferredColorScheme.ls)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
            })
        } header: {
            Spacer()
                .frame(height: 0)
        }
    }
}
