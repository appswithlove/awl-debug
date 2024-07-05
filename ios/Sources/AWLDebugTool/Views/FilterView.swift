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
    
    private var requestMethodsSectionIcon: String {
        return filtersStorage.isRequestMethodsContentShown ? Constants.Image.chevronUp : Constants.Image.chevronDown
    }
    
    private var responseCodesSectionIcon: String {
        return filtersStorage.isResponseCodesContentShown ? Constants.Image.chevronUp : Constants.Image.chevronDown
    }
    
    private var endpointsCodesSectionIcon: String {
        return filtersStorage.isEndpointsContentShown ? Constants.Image.chevronUp : Constants.Image.chevronDown
    }
    
    var body: some View {
        NavigationView {
            Form {
                RequestMethodsSection
                ResponseCodesSection
                EndpointsSection
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
            if filtersStorage.isRequestMethodsContentShown {
                RequestMethodsList
                ActionButtonsSection(deselectAction: networkLogger.deselectAllMethods,
                                     selectAction: networkLogger.selectAllMethods)
            }
        } header: {
            FilterHeader(title: Constants.Headers.requestMethods,
                         icon: requestMethodsSectionIcon,
                         action: { filtersStorage.isRequestMethodsContentShown.toggle() })
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
    
    // MARK: - ResponseCodes
    
    @ViewBuilder private var ResponseCodesSection: some View {
        Section {
            if filtersStorage.isResponseCodesContentShown {
                ResponseCodesList
                ActionButtonsSection(deselectAction: networkLogger.deselectAllCodes,
                                     selectAction: networkLogger.selectAllCodes)
            }
        } header: {
            FilterHeader(title: Constants.Headers.responseCodes,
                         icon: responseCodesSectionIcon,
                         action: { filtersStorage.isResponseCodesContentShown.toggle() })
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
    
    // MARK: - Endpoints
    
    @ViewBuilder private var EndpointsSection: some View {
        Section {
            if filtersStorage.isEndpointsContentShown {
                EndpointsList
                ActionButtonsSection(deselectAction: networkLogger.deselectAllEndpoints,
                                     selectAction: networkLogger.selectAllEndpoints)
            }
        } header: {
            FilterHeader(title: Constants.Headers.endpoints,
                         icon: endpointsCodesSectionIcon,
                         action: { filtersStorage.isEndpointsContentShown.toggle() })
        }
    }
    
    
    @ViewBuilder private var EndpointsList: some View {
        ForEach(Array(networkLogger.endpoints.keys).sorted(), id: \.self) { endpoint in
            Toggle(isOn: Binding<Bool>(
                get: { self.filtersStorage.isEndpointFilterActive(for: endpoint) },
                set: { newValue in
                    self.filtersStorage.updateEndpointFilter(newValue, for: endpoint)
                    networkLogger.endpointsHasChanged = true
                }
            )) {
                VStack(alignment: .leading) {
                    Text(String(endpoint))
                }
            }
        }
    }
    
    // MARK: - Filter Subviews
    
    @ViewBuilder
    private func FilterHeader(title: String, icon: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                action()
            } label: {
                Image(systemName: icon)
                    .padding(6)
            }
        }
    }
    
    @ViewBuilder
    private func ActionButtonsSection(deselectAction: @escaping () -> Void,
                                      selectAction: @escaping() -> Void) -> some View {
        HStack {
            Spacer()
            ActionButton(title: Constants.Buttons.deselectAllBtn) {
                deselectAction()
            }
            ActionButton(title: Constants.Buttons.selectAllBtn) {
                selectAction()
            }
        }
        .padding(.vertical, 4)
    }
    
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
