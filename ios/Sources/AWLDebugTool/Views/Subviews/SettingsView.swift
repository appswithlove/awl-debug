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
    let isEducationalaModeOn: Binding<Bool>
    let networkLogsLimit: Binding<Int>
    let sortingOrder: Binding<Constants.SortingOrder>
    let isDarkModeOn: Binding<Bool>
    
    var body: some View {
        Section {
            VStack {
                Toggle(Constants.Strings.tracking, isOn: didStart)
                    .disabled(true)
                
                if didStart.wrappedValue == false {
                    Text(Constants.Strings.trackingInfo)
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                }
            }
            
            Toggle(Constants.Settings.dynamicData, isOn: isDynamicDataModeOn)
            
            Toggle(Constants.Settings.educationalMode, isOn: isEducationalaModeOn)

            Picker(Constants.Settings.logLimit, selection: networkLogsLimit) {
                ForEach(Constants.Defaults.defaultNumberOfLogs, id: \.self) {
                    Text("\($0)")
                }
            }

            HStack {
                Text(Constants.Settings.sortingOrder)
                Picker(Constants.Settings.sortingOrder, selection: sortingOrder) {
                    ForEach(Constants.SortingOrder.allCases) { sortingOrder in
                        Text(sortingOrder.rawValue)
                            .tag(sortingOrder)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Toggle(Constants.Settings.darkMode, isOn: isDarkModeOn)
        } header: {
            Text(Constants.Headers.settings)
        }
    }
}

#Preview {
    SettingsView(didStart: .constant(true),
                 isDynamicDataModeOn: .constant(true),
                 isEducationalaModeOn: .constant(true),
                 networkLogsLimit: .constant(777),
                 sortingOrder: .constant(Constants.SortingOrder.descending),
                 isDarkModeOn: .constant(true))
}

