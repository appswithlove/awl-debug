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
        NavigationStack {
            Form {
                Toggle(LS.Settings.educationalMode, isOn: $networkLogger.isEducationalaModeOn)
                
                RequestMethodsSection
                ResponseCodesSection
                EndpointsSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(LS.Strings.filters)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isFilterActive = false
                    } label: {
                        Text(LS.Headers.btnDone)
                    }
                }
            }
        }
    }
    
    // MARK: - RequestMethods
    
    @ViewBuilder private var RequestMethodsSection: some View {
        Section {
            if filtersStorage.isRequestMethodsContentShown {
                ActionButtonsSection(deselectAction: networkLogger.deselectAllMethods,
                                     selectAction: networkLogger.selectAllMethods)
                RequestMethodsList
            }
        } header: {
            FilterHeader(title: LS.Headers.requestMethods,
                         isExpanded: filtersStorage.isRequestMethodsContentShown,
                         action: {
                withAnimation {
                    filtersStorage.isRequestMethodsContentShown.toggle()
                }
            })
        }
    }
    
    @ViewBuilder private var RequestMethodsList: some View {
        ForEach(networkLogger.methods.keys.sorted(), id: \.self) { method in
            Toggle(isOn: Binding<Bool>(
                get: { self.filtersStorage.isMethodFilterActive(for: method) },
                set: { newValue in
                    self.filtersStorage.updateMethodFilter(newValue, for: method)
                    networkLogger.methodsAsStaticDict[method] = newValue
                }
            )) {
                VStack(alignment: .leading) {
                    Text(String(method))
                    if networkLogger.isEducationalaModeOn {
                        Text(Constants.RequestMethod[method] ?? LS.Strings.unknownValue)
                            .font(.caption2)
                    }
                }
            }
        }
    }
    
    // MARK: - ResponseCodes
    
    @ViewBuilder private var ResponseCodesSection: some View {
        Section {
            if filtersStorage.isResponseCodesContentShown {
                ActionButtonsSection(deselectAction: networkLogger.deselectAllCodes,
                                     selectAction: networkLogger.selectAllCodes)
                ResponseCodesList
            }
        } header: {
            FilterHeader(title: LS.Headers.responseCodes,
                         isExpanded: filtersStorage.isResponseCodesContentShown,
                         action: {
                withAnimation {
                    filtersStorage.isResponseCodesContentShown.toggle()
                }
            })
        }
    }
    
    @ViewBuilder private var ResponseCodesList: some View {
        ForEach(networkLogger.codes.keys.sorted(), id: \.self) { code in
            Toggle(isOn: Binding<Bool>(
                get: { self.filtersStorage.isCodeFilterActive(for: code) },
                set: { newValue in
                    self.filtersStorage.updateCodeFilter(newValue, for: code)
                    networkLogger.codesAsStaticDict[code] = newValue
                }
            )) {
                VStack(alignment: .leading) {
                    Text(String(code))
                    if networkLogger.isEducationalaModeOn {
                        Text(Constants.ResponseCodes[code] ?? LS.Strings.unknownValue)
                            .font(.caption2)
                    }
                }
            }
        }
    }
    
    // MARK: - Endpoints
    
    @ViewBuilder private var EndpointsSection: some View {
        Section {
            if filtersStorage.isEndpointsContentShown {
                ActionButtonsSection(deselectAction: networkLogger.deselectAllEndpoints,
                                     selectAction: networkLogger.selectAllEndpoints)
                EndpointsList
            }
        } header: {
            FilterHeader(title: LS.Headers.endpoints,
                         isExpanded: filtersStorage.isEndpointsContentShown,
                         action: {
                withAnimation {
                    filtersStorage.isEndpointsContentShown.toggle()
                }
            })
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
    private func FilterHeader(title: String, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                action()
            } label: {
                Image.with(icon: isExpanded ? .chevronUp : .chevronDown)
                    .padding(6)
            }
        }
    }
    
    @ViewBuilder
    private func ActionButtonsSection(deselectAction: @escaping () -> Void,
                                      selectAction: @escaping() -> Void) -> some View {
        HStack {
            Spacer()
            ActionButton(title: LS.Buttons.deselectAllBtn) {
                deselectAction()
            }
            ActionButton(title: LS.Buttons.selectAllBtn) {
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

#Preview {
    FilterView(isFilterActive: .constant(true))
}
