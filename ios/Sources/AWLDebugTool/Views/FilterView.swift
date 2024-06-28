//
//  FilterView.swift
//
//
//  Created by Hrvoje Hajduković on 27.06.2024..
//

import SwiftUI

struct FilterView: View {
    @ObservedObject private var networkLogger = AWLDebugTool.shared.networkLogger
    @ObservedObject private var filtersStorage = FiltersStorage()
    
    @Binding var isFilterActive: Bool
    
    var body: some View {
        NavigationView {
            Form {
                RequestMethodsSection
                ResponseCodesSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(Constants.Strings.filters)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isFilterActive = false
                    } label: {
                        Text(Constants.Headers.btnDone)
                    }
                }
            }
        }
    }
    
    // MARK: - RequestMethods
    
    @ViewBuilder private var RequestMethodsSection: some View {
        Section {
            RequestMethodsList
            RequestMethodsActions
        } header: {
            RequestMethodsHeader
        }
    }
    
    @ViewBuilder private var RequestMethodsList: some View {
        ForEach(Array(networkLogger.methods.keys).sorted(), id: \.self) { method in
            Toggle(isOn: Binding<Bool>(
                get: { self.filtersStorage.isMethodFilterActive(for: method) },
                set: { newValue in
                    self.filtersStorage.updateMethodFilter(newValue, for: method)
                    networkLogger.methods[method] = newValue
                }
            )) {
                VStack(alignment: .leading) {
                    Text(String(method))
                    Text(Constants.RequestMethod[method] ?? Constants.Strings.unknownValue)
                        .font(.caption2)
                }
            }
        }
    }
    
    @ViewBuilder private var RequestMethodsActions: some View {
        HStack {
            Spacer()
            ActionButton(title: Constants.Buttons.deselectAllBtn) {
                networkLogger.deselectAllMethods()
            }
            ActionButton(title: Constants.Buttons.selectAllBtn) {
                networkLogger.selectAllMethods()
            }
        }
    }
    
    @ViewBuilder private var RequestMethodsHeader: some View {
        HStack {
            Text(Constants.Headers.requestMethods)
            // TODO: add collapsible icon
        }
    }
    
    // MARK: - ResponseCodes
    
    @ViewBuilder private var ResponseCodesSection: some View {
        Section {
            ResponseCodesList
            ResponseCodesActions
        } header: {
            ResponseCodesHeader
        }
    }
    
    @ViewBuilder private var ResponseCodesList: some View {
        ForEach(Array(networkLogger.codes.keys).sorted(), id: \.self) { code in
            Toggle(isOn: Binding<Bool>(
                get: { self.filtersStorage.isCodeFilterActive(for: code) },
                set: { newValue in
                    self.filtersStorage.updateCodeFilter(newValue, for: code)
                    networkLogger.codes[code] = newValue
                }
            )) {
                VStack(alignment: .leading) {
                    Text(String(code))
                    Text(Constants.ResponseCodes[code] ?? Constants.Strings.unknownValue)
                        .font(.caption2)
                }
            }
        }
    }
    
    @ViewBuilder private var ResponseCodesActions: some View {
        HStack {
            Spacer()
            ActionButton(title: Constants.Buttons.deselectAllBtn) {
                networkLogger.deselectAllCodes()
            }
            ActionButton(title: Constants.Buttons.selectAllBtn) {
                networkLogger.selectAllCodes()
            }
        }
    }
    
    @ViewBuilder private var ResponseCodesHeader: some View {
        HStack {
            Text(Constants.Headers.responseCodes)
            // TODO: add collapsible icon
        }
    }
    
    // MARK: - Buttons
    
    @ViewBuilder
    private func ActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(title)
        }
        .buttonStyle(.borderedProminent)
    }
}
