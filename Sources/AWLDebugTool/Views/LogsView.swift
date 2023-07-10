//
//  LogsView.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 07.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import SwiftUI

public struct LogsView: View {
    @EnvironmentObject private var networkLogsService: AWLDebugTool
    @State private var searchText = Constants.Strings.emptyString
    
    public init() {}
    
    var filteredLogs: [NetworkLog] {
        if searchText.isEmpty {
            return networkLogsService.networkTraffic
        } else {
            return networkLogsService.networkTraffic.filter { $0.method.localizedCaseInsensitiveContains(searchText) ||
                $0.url.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Number of requests: \(filteredLogs.count) / \(networkLogsService.logLimit)")
                .padding(.horizontal)
                .padding(.bottom, 8)
                .font(.callout)
            List(filteredLogs) { log in
                VStack(alignment: .leading) {
                    HStack {
                        Text("\(log.date)")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    HStack {
                        Text(log.method)
                        Text(log.url)
                    }
                    .font(.callout)
                    .foregroundColor(.primary)
                    .padding(.vertical, 2)
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
