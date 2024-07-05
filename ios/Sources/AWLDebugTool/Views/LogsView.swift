//
//  LogsView.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 07.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import SwiftUI

public struct LogsView: View {
    @Environment(\.dismiss)
    var dismiss
    
    @ObservedObject private var debugTool = AWLDebugTool.shared
    @ObservedObject private var networkLogger = AWLDebugTool.shared.networkLogger
    
    @State private var searchText = Constants.Strings.emptyString
    
    @State private var isFilterActive = false
    
    let onClose: () -> ()
    
    public init(onClose: @escaping () -> ()) {
        self.onClose = onClose
    }
    
    private var filteredLogs: [NetworkLog] {
        let searched = searchText.isEmpty ? networkLogger.networkTraffic : networkLogger.networkTraffic.filter {
            $0.method.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
        
        let filteredByRequestMethods = searched.filter { log in
            if let isActive = networkLogger.methods[log.method] {
                return isActive
            }
            return false
        }
        
        let filteredByResponseCodes = filteredByRequestMethods.filter { log in
            if let isActive = networkLogger.codes[log.statusCode] {
                return isActive
            }
            return false
        }

        let filteredByEndpoints = filteredByResponseCodes.filter { log in
            if let isActive = networkLogger.endpoints[networkLogger.findFirstMatch(in: log.url, with: Constants.Regex.endpointsPattern) ?? ""] {
                return isActive
            }
            return false
        }
        
        return filteredByEndpoints.sorted { log1, log2 in
            switch networkLogger.sortingOrder {
            case .ascending:
                return log1.date < log2.date
            case .descending:
                return log1.date > log2.date
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = Constants.Date.dateFormatSecondary
        return df
    }()
    
    private func colorFor(statusCode: Int) -> Color {
        switch statusCode {
        case 200...299: return .green
        case 300...399: return .blue
        case 400...499: return .orange
        case 500...599: return .red
        default: return .purple
        }
    }
    
    var isSortingOrderButtonDisabled: Bool {
        return networkLogger.networkTraffic.count < 2 ? true : false
    }
    
    var isDeleteLogsButtonDisabled: Bool {
        return networkLogger.networkTraffic.isEmpty ? true : false
    }
    
    var isFilterChangedByUser: String {
        return networkLogger.methods.values.contains(false) || networkLogger.codes.values.contains(false) ?
        Constants.Image.filtersSet : Constants.Image.filtersUnset
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogsOptions
            LogsList
        }
        .overlay {
            EmptyLogsList
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(Constants.Strings.logs)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onClose()
                    dismiss()
                } label: {
                    Text(Constants.Headers.btnClose)
                }
            }
        }
    }
    
    @ViewBuilder var EmptyLogsList: some View {
        if filteredLogs.isEmpty {
            Text(Constants.Strings.emptyListOfLogs)
        }
    }
    
    @ViewBuilder var LogsOptions: some View {
        HStack(alignment: .center) {
            NumberOfRequestsText
            Spacer()
            SortingOrderToggleButton
            FilterLogsButton
            RemoveAllLogsButton
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .sheet(isPresented: $isFilterActive) {
            FilterView(isFilterActive: $isFilterActive)
        }
    }
    
    @ViewBuilder var NumberOfRequestsText: some View {
        Group {
            Text(Constants.Strings.numberOfLogs) +
            Text("\(filteredLogs.count) / \(networkLogger.networkLogsLimit)")
                .bold()
        }
        .font(.system(size: 12))
    }
    
    @ViewBuilder var FilterLogsButton: some View {
        Button {
            isFilterActive = true
        } label: {
            Image(systemName: isFilterChangedByUser)
        }
        .padding(4)
    }
    
    @ViewBuilder var SortingOrderToggleButton: some View {
        Button {
            networkLogger.sortingOrder = networkLogger.sortingOrder == .ascending ? .descending : .ascending
        } label: {
            Image(systemName: Constants.Image.sortingOrder)
        }
        .padding(4)
        .disabled(isSortingOrderButtonDisabled)
    }
    
    @ViewBuilder var RemoveAllLogsButton: some View {
        Button {
            networkLogger.deleteNetworkLogs()
        } label: {
            Image(systemName: Constants.Image.clear)
                .foregroundColor(.red)
                .opacity(isDeleteLogsButtonDisabled ? Constants.Values.disabledBtnOpacity : Constants.Values.enabledBtnOpacity)
        }
        .padding(4)
        .disabled(isDeleteLogsButtonDisabled)
    }
    
    @ViewBuilder var LogsList: some View {
        List(filteredLogs) { log in
            VStack(alignment: .leading) {
                LogDate(date: log.date)
                LogUrl(url: log.url)
                LogInfo(method: log.method, statusCode: log.statusCode, duration: log.duration)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Constants.Strings.searchLogs)
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .padding(.leading, -4)
        .padding(.trailing, 16)
    }
    
    @ViewBuilder 
    private func LogDate(date: Date) -> some View {
        Text(dateFormatter.string(from: date))
            .font(.caption2)
            .foregroundColor(.gray)
    }
    
    @ViewBuilder 
    private func LogUrl(url: String) -> some View {
        HStack {
            Text(url)
        }
        .font(.callout)
        .foregroundColor(.primary)
        .padding(.vertical, 2)
    }
    
    @ViewBuilder 
    private func LogInfo(method: String, statusCode: Int, duration: Int) -> some View {
        HStack {
            Text(method)
            Text("\(statusCode)")
            Text("(\(duration)ms)")
        }
        .font(.callout)
        .foregroundColor(colorFor(statusCode: statusCode))
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LogsView(onClose: {})
        }
    }
}
