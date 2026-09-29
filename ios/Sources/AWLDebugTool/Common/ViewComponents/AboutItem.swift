//
//  AboutItem.swift
//  
//
//  Created by Hrvoje Hajduković on 19.09.2025..
//

import SwiftUI

struct AboutItem: View {
    let iconName: String
    let iconColor: Color
    let text: String
    
    init(iconName: String, iconColor: Color = .gray, text: String) {
        self.iconName = iconName
        self.iconColor = iconColor
        self.text = text
    }
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 16, height: 16)
                .padding(.trailing, 4)
            Text(text)
            Spacer()
        }
    }
}

#Preview {
    AboutItem(iconName: "apple.logo",
              iconColor: .blue,
              text: "iPhone 16 Pro")
}
