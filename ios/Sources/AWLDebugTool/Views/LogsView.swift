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
    
    let onClose: () -> ()
    
    public init(onClose: @escaping () -> ()) {
        self.onClose = onClose
    }
    
    private var filteredLogs: [NetworkLog] {
        if searchText.isEmpty {
            return networkLogger.networkTraffic
        } else {
            return networkLogger.networkTraffic.filter { $0.method.localizedCaseInsensitiveContains(searchText) ||
                $0.url.localizedCaseInsensitiveContains(searchText)
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
    
    var isDeleteLogsButtonDisabled: Bool {
        return networkLogger.networkTraffic.isEmpty ? true : false
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogsOptions
            LogsList
        }
    }
    
    @ViewBuilder var LogsOptions: some View {
        HStack(alignment: .center) {
            NumberOfRequestsText
            Spacer()
            RemoveAllLogsButton
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder var NumberOfRequestsText: some View {
        Group {
            Text(Constants.Strings.numberOfLogs) +
            Text("\(filteredLogs.count) / \(networkLogger.networkLogsLimit)")
                .bold()
        }
        .font(.system(size: 12))
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
        .listStyle(.grouped)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Constants.Strings.searchLogs)
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
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
