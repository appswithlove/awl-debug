//
//  LogsView.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 07.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import SwiftUI

public struct LogsView: View {
    @ObservedObject private var debugTool = AWLDebugTool.shared
    @ObservedObject private var networkLogger = AWLDebugTool.shared.networkLogger
    
    @State private var searchText = Constants.Strings.emptyString
    
    public init() {}
    
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
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Number of requests: \(filteredLogs.count) / \(networkLogger.networkLogsLimit)")
                .padding(.horizontal)
                .padding(.bottom, 8)
                .font(.callout)
            List(filteredLogs) { log in
                VStack(alignment: .leading) {
                    Text(dateFormatter.string(from: log.date))
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    
                    HStack {
                        Text(log.url)
                    }
                    .font(.callout)
                    .foregroundColor(.primary)
                    .padding(.vertical, 2)
                    
                    HStack {
                        Text(log.method)
                        Text("\(log.statusCode)")
                        Text("(\(log.duration)ms)")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            .listStyle(.grouped)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Constants.Strings.searchLogs)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
        }
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LogsView()
        }
    }
}
