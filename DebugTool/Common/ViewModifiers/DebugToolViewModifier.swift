//
//  DebugToolViewModifier.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 21.06.2023..
//

import SwiftUI

public struct DebugToolViewModifier: ViewModifier {
    @State private var isShowingDebugTool = false
    var fcmToken: String = Constants.Strings.unknownValue

    public func body(content: Content) -> some View {
        content
            .onTapGesture(count: 3) {
                isShowingDebugTool = true
            }
            .sheet(isPresented: $isShowingDebugTool, content: {
                DebugView(fcmToken: fcmToken)
            })
    }
}

extension View {
    public func includeDebugTool(fcmToken: String) -> some View {
         modifier(DebugToolViewModifier(fcmToken: fcmToken))
    }
}
