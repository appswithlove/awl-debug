//
//  Color.swift
//  
//
//  Created by Hrvoje Hajduković on 05.09.2025..
//

import SwiftUI
import UIKit

extension Color {
    static let logTimeColor = Color("logTimeColor", bundle: .module)

    // Status colors for text and dots, at least 4.5:1 on the panel's backgrounds in light and dark mode
    // (the same values as on Android). The plain system colors are too light for text in light mode.
    static let statusPositive = Color(light: 0x2E7D32, dark: 0x4CAF50)
    static let statusRedirect = Color(light: 0x2F6FDE, dark: 0x5B8DEF)
    static let statusWarning = Color(light: 0x9A6200, dark: 0xF3B45B)
    static let statusError = Color(light: 0xC43B3B, dark: 0xFF6B6B)
    static let statusInfo = Color(light: 0x6439AF, dark: 0xB39DDB)
    static let statusNeutral = Color(light: 0x5F5F66, dark: 0xAEAEB2)

    private init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}
