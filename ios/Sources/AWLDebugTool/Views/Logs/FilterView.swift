//
//  FilterView.swift
//
//

import SwiftUI

struct FilterView: View {
    @ObservedObject private var networkLogger = AWLDebugTool.shared.networkLogger
    @ObservedObject private var filtersStorage = FiltersStorage()
    
    @Binding var isFilterActive: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(LS.Settings.educationalMode, isOn: $networkLogger.isEducationalaModeOn)
                    Toggle(LS.Settings.dynamicData, isOn: $networkLogger.isDynamicDataModeOn)
                }

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
                if networkLogger.methods.isEmpty {
                    NoValuesYet
                } else {
                    ActionButtonsSection(deselectAction: networkLogger.deselectAllMethods,
                                         selectAction: networkLogger.selectAllMethods)
                    RequestMethodsList
                }
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
                if networkLogger.codes.isEmpty {
                    NoValuesYet
                } else {
                    ActionButtonsSection(deselectAction: networkLogger.deselectAllCodes,
                                         selectAction: networkLogger.selectAllCodes)
                    ResponseCodesList
                }
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
                if networkLogger.endpoints.isEmpty {
                    NoValuesYet
                } else {
                    ActionButtonsSection(deselectAction: networkLogger.deselectAllEndpoints,
                                         selectAction: networkLogger.selectAllEndpoints)
                    EndpointsList
                }
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

    /// Values come from the captured traffic; without requests there is nothing to filter yet.
    private var NoValuesYet: some View {
        Text(LS.Strings.emptyListOfLogs)
            .foregroundStyle(.secondary)
    }
    
    /// The whole header toggles the group; VoiceOver reads it as one button with its state.
    @ViewBuilder
    private func FilterHeader(title: String, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image.with(icon: isExpanded ? .chevronUp : .chevronDown)
                    .foregroundStyle(.tint)
                    .padding(6)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(isExpanded ? LS.Buttons.expanded : LS.Buttons.collapsed)
    }
    
    @ViewBuilder
    private func ActionButtonsSection(deselectAction: @escaping () -> Void,
                                      selectAction: @escaping() -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Spacer()
                ActionButton(title: LS.Buttons.deselectAllBtn) {
                    deselectAction()
                }
                ActionButton(title: LS.Buttons.selectAllBtn) {
                    selectAction()
                }
            }
            VStack(alignment: .trailing) {
                ActionButton(title: LS.Buttons.deselectAllBtn) {
                    deselectAction()
                }
                ActionButton(title: LS.Buttons.selectAllBtn) {
                    selectAction()
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
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
