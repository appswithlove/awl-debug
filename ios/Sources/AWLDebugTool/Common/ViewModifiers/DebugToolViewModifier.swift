//
//  DebugToolViewModifier.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 21.06.2023..
//

import SwiftUI

extension DebugToolViewModifier {
    public enum ShowDebugToolEvents {
        case userDidTakeScreenshot
        case threeTaps
    }
    
    class ViewModel: ObservableObject {
        @Published var isShowingDebugTool = false
        var showDebugToolEvents: [DebugToolViewModifier.ShowDebugToolEvents] = []
        
        init() {
            NotificationCenter.default.addObserver(self, selector: #selector(userDidTakeScreenshotNotification),
                                                   name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        }
        
        @objc private func userDidTakeScreenshotNotification() {
            if showDebugToolEvents.contains(.userDidTakeScreenshot) {
                isShowingDebugTool = true;
            }
        }
        
        func threeTapsAction() {
            if showDebugToolEvents.contains(.threeTaps) {
                isShowingDebugTool = true
            }
        }
    }
}

public struct DebugToolViewModifier: ViewModifier {
    @StateObject private var viewModel = ViewModel()
    let fcmToken: String?
    let showDebugToolEvents: [DebugToolViewModifier.ShowDebugToolEvents]
    let customView: (() -> any View)?

    public func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(count: 3) {
                viewModel.threeTapsAction()
            }
            .sheet(isPresented: $viewModel.isShowingDebugTool, content: {
                DebugView(fcmToken: fcmToken, customView: customView)
            })
            .onAppear {
                viewModel.showDebugToolEvents = showDebugToolEvents
            }
    }
}

extension View {
    public func includeDebugTool(fcmToken: String? = nil,
                                 showDebugToolEvents: [DebugToolViewModifier.ShowDebugToolEvents] = [.threeTaps],
                                 customView: (() -> any View)? = nil) -> some View {
        modifier(DebugToolViewModifier(fcmToken: fcmToken, showDebugToolEvents: showDebugToolEvents, customView: customView))
    }
}
