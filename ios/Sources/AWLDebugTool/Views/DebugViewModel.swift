//
//  DebugViewModel.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 19.09.2025..
//

import SwiftUI

class DebugViewModel: ObservableObject {
    @Published var isShowingDeleteNetworkLogs = false
    @Published var isShowingDeleteUserDefaults = false
    @Published var isShowingFileExporter = false

    @Published var document = TextDocument(text: "")
    @Published var filename: String = {
        let date = Date.now
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        return "NL\(df.string(from: date)).txt"
    }()
    
    func showDeleteNetworkLogsAlert() {
        isShowingDeleteNetworkLogs = true
    }
    
    func showDeleteUserDefaultsAlert() {
        isShowingDeleteUserDefaults = true
    }
    
    func showFileExporter() {
        isShowingFileExporter = true
    }
}
