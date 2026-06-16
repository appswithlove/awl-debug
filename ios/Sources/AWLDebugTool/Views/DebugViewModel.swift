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
        static let isPerformanceWidgetVisible = "DebugView.isPerformanceWidgetVisible"
        static let preferredFontSize = "DebugView.preferredFontSize"
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
    enum AppFontSize: String, CaseIterable {
        case system
        case extraSmall
        case small
        case medium
        case large
        case xLarge
        case xxLarge
        case xxxLarge
        case accessibilityM
        case accessibilityL
        case accessibilityXL
        case accessibilityXXL
        case accessibilityXXXL

        var sizeCategory: ContentSizeCategory? {
            switch self {
            case .system: return nil
            case .extraSmall: return .extraSmall
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            case .xLarge: return .extraLarge
            case .xxLarge: return .extraExtraLarge
            case .xxxLarge: return .extraExtraExtraLarge
            case .accessibilityM: return .accessibilityMedium
            case .accessibilityL: return .accessibilityLarge
            case .accessibilityXL: return .accessibilityExtraLarge
            case .accessibilityXXL: return .accessibilityExtraExtraLarge
            case .accessibilityXXXL: return .accessibilityExtraExtraExtraLarge
            }
        }

        var ls: String {
            switch self {
            case .system: return "System"
            case .extraSmall: return "Extra Small"
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large (default)"
            case .xLarge: return "Extra Large"
            case .xxLarge: return "XX Large"
            case .xxxLarge: return "XXX Large"
            case .accessibilityM: return "Accessibility M"
            case .accessibilityL: return "Accessibility L"
            case .accessibilityXL: return "Accessibility XL"
            case .accessibilityXXL: return "Accessibility XXL"
            case .accessibilityXXXL: return "Accessibility XXXL"
            }
        }
    }
}

class DebugViewModel: ObservableObject {
    @AppStorage(DebugView.Keys.preferredColorScheme)
    var preferredColorScheme: DebugView.AppColorScheme = .auto
    
    @AppStorage(DebugView.Keys.isPerformanceWidgetVisible)
    var isPerformanceWidgetVisible: Bool = false

    @AppStorage(DebugView.Keys.preferredFontSize)
    var preferredFontSize: DebugView.AppFontSize = .system

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
