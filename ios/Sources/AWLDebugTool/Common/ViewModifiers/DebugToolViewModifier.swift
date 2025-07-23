//
//  DebugToolViewModifier.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 21.06.2023..
//

import SwiftUI

public struct DebugToolViewModifier: ViewModifier {
    @State private var isShowingDebugTool = false
    let fcmToken: String?
    let customView: (() -> View)?

    public func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(count: 3) {
                isShowingDebugTool = true
            }
            .sheet(isPresented: $isShowingDebugTool, content: {
                DebugView(fcmToken: fcmToken, customView: customView)
            })
    }
}

extension View {
    public func includeDebugTool(fcmToken: String? = nil, customView: (() -> View)? = nil) -> some View {
        modifier(DebugToolViewModifier(fcmToken: fcmToken, customView: customView))
    }
}
