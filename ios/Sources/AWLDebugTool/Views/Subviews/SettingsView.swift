//
//  SettingsView.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct SettingsView: View {
    let didStart: Binding<Bool>
    let isDynamicDataModeOn: Binding<Bool>
    let networkLogsLimit: Binding<Int>
    let sortingOrder: Binding<Constants.SortingOrder>
    let isDarkModeOn: Binding<Bool>
    
    var body: some View {
        Section {
            VStack {
                Toggle(LS.Strings.tracking, isOn: didStart)
                    .disabled(true)
                
                if didStart.wrappedValue == false {
                    Text(LS.Strings.trackingInfo)
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                }
            }
            
            Toggle(LS.Settings.dynamicData, isOn: isDynamicDataModeOn)
            
            Picker(LS.Settings.logLimit, selection: networkLogsLimit) {
                ForEach(Constants.Defaults.defaultNumberOfLogs, id: \.self) {
                    Text("\($0)")
                }
            }

            HStack {
                Text(LS.Settings.sortingOrder)
                Picker(LS.Settings.sortingOrder, selection: sortingOrder) {
                    ForEach(Constants.SortingOrder.allCases) { sortingOrder in
                        Text(sortingOrder.rawValue)
                            .tag(sortingOrder)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Toggle(LS.Settings.darkMode, isOn: isDarkModeOn)
        } header: {
            Text(LS.Headers.settings)
        }
    }
}

#Preview {
    SettingsView(didStart: .constant(true),
                 isDynamicDataModeOn: .constant(true),
                 networkLogsLimit: .constant(777),
                 sortingOrder: .constant(Constants.SortingOrder.descending),
                 isDarkModeOn: .constant(true))
}

