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
        @AppStorage(DebugView.Keys.preferredColorScheme)
        var preferredColorScheme: DebugView.AppColorScheme = .auto
        
        @AppStorage(DebugView.Keys.isPerformanceWidgetVisible)
        var isPerformanceWidgetVisible: Bool = false

        @AppStorage(DebugView.Keys.preferredFontSize)
        var preferredFontSize: DebugView.AppFontSize = .system
        
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
    @State private var widgetOffset: CGSize = .zero
    @State private var widgetPosition: CGPoint = CGPoint(x: 200, y: 100)
    let fcmToken: String?
    let showDebugToolEvents: [DebugToolViewModifier.ShowDebugToolEvents]
    let customView: (() -> any View)?

    public func body(content: Content) -> some View {
        content
            .applyFontSize(viewModel.preferredFontSize.sizeCategory)
            .preferredColorScheme(viewModel.preferredColorScheme.colorScheme)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 3)
                    .onEnded {
                        viewModel.threeTapsAction()
                    }
            )
            .overlay {
                VStack {
                    ZStack {
                        let text = "AWL \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")" +
                        " (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"
                        Text(text).foregroundStyle(Color(UIColor.label))
                    }
                    .background(Color(UIColor.systemBackground))
                    .font(.system(size: 8))
                    Spacer()
                }
                .ignoresSafeArea()
            }
            .overlay {
                if viewModel.isPerformanceWidgetVisible {
                    GeometryReader { geometry in
                        PerformanceWidgetView(cpuMonitor: AWLDebugTool.shared.cpuMonitor, ramMonitor: AWLDebugTool.shared.ramMonitor, mainThreadMonitor: AWLDebugTool.shared.mainThreadMonitor)
                            .position(
                                x: min(max(widgetPosition.x + widgetOffset.width, 0), geometry.size.width),
                                y: min(max(widgetPosition.y + widgetOffset.height, 0), geometry.size.height)
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        widgetOffset = value.translation
                                    }
                                    .onEnded { value in
                                        widgetPosition = CGPoint(
                                            x: min(max(widgetPosition.x + value.translation.width, 0), geometry.size.width),
                                            y: min(max(widgetPosition.y + value.translation.height, 0), geometry.size.height)
                                        )
                                        widgetOffset = .zero
                                    }
                            )
                    }
                }
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
    @ViewBuilder
    fileprivate func applyFontSize(_ size: ContentSizeCategory?) -> some View {
        if let size {
            self.environment(\.sizeCategory, size)
        } else {
            self
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
