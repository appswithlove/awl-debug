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
    let iconName: String
    let iconColor: IconColor
    let isDisabled: Bool
    let action: () -> Void
    
    init(text: String,
         subtext: String? = nil,
         iconName: String,
         iconColor: IconColor,
         isDisabled: Bool = false,
         action: @escaping () -> Void
    ) {
        self.text = text
        self.subtext = subtext ?? ""
        self.iconName = iconName
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
                Image(systemName: iconName)
                    .foregroundColor(iconColor.color)
                    .opacity(isDisabled ? Constants.Values.disabledBtnOpacity : Constants.Values.enabledBtnOpacity)
            }
        }
        .disabled(isDisabled)
    }
}
#Preview {
    ProprietaryActionButton(text: Constants.Actions.clearAppUserDefaults,
                            iconName: Constants.Image.clear,
                            iconColor: IconColor.deletion,
                            isDisabled: false,
                            action: {})
}
