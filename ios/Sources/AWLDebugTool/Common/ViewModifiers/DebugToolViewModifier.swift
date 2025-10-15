//
//  DebugToolViewModifier.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 21.06.2023..
//

import SwiftUI

extension DebugToolViewModifier {
    class ViewModel: ObservableObject {
        @Published var isShowingDebugTool = false
        
        init() {
            NotificationCenter.default.addObserver(self, selector: #selector(userDidTakeScreenshotNotification),
                                                   name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        }
        
        @objc private func userDidTakeScreenshotNotification() {
            isShowingDebugTool = true;
        }
    }
}

public struct DebugToolViewModifier: ViewModifier {
    @StateObject private var viewModel = ViewModel()
    let fcmToken: String?
    let customView: (() -> any View)?

    public func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(count: 3) {
                viewModel.isShowingDebugTool = true
            }
            .sheet(isPresented: $viewModel.isShowingDebugTool, content: {
                DebugView(fcmToken: fcmToken, customView: customView)
            })
    }
}

extension View {
    public func includeDebugTool(fcmToken: String? = nil, customView: (() -> any View)? = nil) -> some View {
        modifier(DebugToolViewModifier(fcmToken: fcmToken, customView: customView))
    }
}
