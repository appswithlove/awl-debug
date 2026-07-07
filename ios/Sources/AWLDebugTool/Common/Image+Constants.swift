//
//  Image+Constants.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 02.06.2026.
//

import SwiftUI

extension Image {
    static func with(icon: AppIcon) -> Image {
        Image(systemName: icon.rawValue)
    }
    
    enum AppIcon: String, CaseIterable, Identifiable {
        case clear = "trash"
        case export = "square.and.arrow.up"
        case crash = "pip.remove"
        case play = "play.fill"
        case pause = "pause.fill"
        case sortAscending = "arrow.up"
        case sortDescending = "arrow.down"
        case filtersUnset = "line.3.horizontal.decrease.circle"
        case filtersSet = "line.3.horizontal.decrease.circle.fill"
        case chevronUp = "chevron.up"
        case chevronDown = "chevron.down"
        case gear = "gear"
        
        var id: String { self.rawValue }
    }
}

#Preview {
    ForEach(Image.AppIcon.allCases) {
        Image.with(icon: $0)
    }
}
