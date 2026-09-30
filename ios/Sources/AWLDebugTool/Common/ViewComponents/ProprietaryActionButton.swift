//
//  ProprietaryActionButton.swift
//  
//
//  Created by Hrvoje Hajduković on 19.09.2025..
//

import SwiftUI

enum IconColor {
    case action
    case deletion
    
    var color: Color {
        switch self {
        case .action:
            return .blue
        case .deletion:
            return .red
        }
    }
}

/// A form row with a text and a trailing icon; destructive (red) for `.deletion`.
struct ProprietaryActionButton: View {
    let text: String
    let icon: Image.AppIcon
    let iconColor: IconColor
    let isDisabled: Bool
    /// Shows a spinner instead of the icon while the action runs.
    let isInProgress: Bool
    let action: () -> Void
    
    init(text: String,
         icon: Image.AppIcon,
         iconColor: IconColor,
         isDisabled: Bool = false,
         isInProgress: Bool = false,
         action: @escaping () -> Void
    ) {
        self.text = text
        self.icon = icon
        self.iconColor = iconColor
        self.isDisabled = isDisabled
        self.isInProgress = isInProgress
        self.action = action
    }
    
    var body: some View {
        Button(role: iconColor == .deletion ? .destructive : nil, action: action) {
            HStack {
                Text(text)
                Spacer()
                if isInProgress {
                    ProgressView()
                } else {
                    Image.with(icon: icon)
                        .foregroundStyle(iconColor.color)
                        .opacity(isDisabled ? Constants.Values.disabledBtnOpacity : Constants.Values.enabledBtnOpacity)
                        .accessibilityHidden(true)
                }
            }
        }
        .disabled(isDisabled || isInProgress)
    }
}
#Preview {
    ProprietaryActionButton(text: LS.ClearData.button,
                            icon: .clear,
                            iconColor: IconColor.deletion,
                            isDisabled: false,
                            action: {})
}
