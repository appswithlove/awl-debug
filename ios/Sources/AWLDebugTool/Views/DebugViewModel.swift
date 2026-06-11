//
//  DebugViewModel.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 19.09.2025..
//

import SwiftUI

extension DebugView {
    enum Keys {
        static let preferredColorScheme = "DebugView.userPreferredColorScheme"
    }
    
    enum AppColorScheme: String, CaseIterable {
        case auto
        case light
        case dark
        
        var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .auto: return nil
            }
        }
        
        var ls: String {
            return rawValue
        }
    }
}

class DebugViewModel: ObservableObject {
    @AppStorage(DebugView.Keys.preferredColorScheme)
    var preferredColorScheme: DebugView.AppColorScheme = .auto
    
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
