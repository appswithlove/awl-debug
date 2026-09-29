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

struct ProprietaryActionButton: View {
    let text: String
    let subtext: String
    let icon: Image.AppIcon
    let iconColor: IconColor
    let isDisabled: Bool
    let action: () -> Void
    
    init(text: String,
         subtext: String? = nil,
         icon: Image.AppIcon,
         iconColor: IconColor,
         isDisabled: Bool = false,
         action: @escaping () -> Void
    ) {
        self.text = text
        self.subtext = subtext ?? ""
        self.icon = icon
        self.iconColor = iconColor
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Group {
                    Text(text)
                    Text(subtext)
                        .font(.caption)
                }
                Spacer()
                Image.with(icon: icon)
                    .foregroundColor(iconColor.color)
                    .opacity(isDisabled ? Constants.Values.disabledBtnOpacity : Constants.Values.enabledBtnOpacity)
            }
        }
        .disabled(isDisabled)
    }
}
#Preview {
    ProprietaryActionButton(text: LS.ClearData.button,
                            icon: .clear,
                            iconColor: IconColor.deletion,
                            isDisabled: false,
                            action: {})
}
