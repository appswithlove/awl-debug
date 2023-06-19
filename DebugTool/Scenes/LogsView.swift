//
//  LogsView.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 07.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import SwiftUI

public struct LogsView: View {
    @EnvironmentObject private var networkLogsService: NetworkLogsService
    @State private var searchText = ""
    
    public init() {}
    
    var filteredLogs: [NetworkLog] {
        if searchText.isEmpty {
            return networkLogsService.networkTraffic
        } else {
            return networkLogsService.networkTraffic.filter { $0.method.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Number of requests: \(filteredLogs.count) / \(networkLogsService.logLimit)")
                .padding(.horizontal)
                .padding(.bottom, 8)
            List(filteredLogs) { log in
                HStack {
                    Text(log.method)
                    Text(log.url)
                }
            }
            .listStyle(.grouped)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search logs")
            .autocorrectionDisabled(true)
        }
        .onAppear {
            networkLogsService.loadNetworkLogs()
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
