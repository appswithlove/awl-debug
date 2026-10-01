//
//  DebugToolViewModifier.swift
//  DebugTool
//

import SwiftUI

extension DebugToolViewModifier {
    /// Replaced by `AWLDebugConfig.triggers`.
    public enum ShowDebugToolEvents {
        case userDidTakeScreenshot
        /// Three quick taps with one finger, now `AWLDebugTrigger.tripleTap`.
        case threeTaps

        var trigger: AWLDebugTrigger {
            switch self {
            case .userDidTakeScreenshot: return .screenshot
            case .threeTaps: return .tripleTap
            }
        }
    }
    
    class ViewModel: ObservableObject {
        @AppStorage(DebugView.Keys.preferredColorScheme)
        var preferredColorScheme: DebugView.AppColorScheme = .auto
        
        @AppStorage(DebugView.Keys.isPerformanceWidgetVisible)
        var isPerformanceWidgetVisible: Bool = false

        @AppStorage(DebugView.Keys.preferredFontSize)
        var preferredFontSize: DebugView.AppFontSize = .system
        
    }
}

public struct DebugToolViewModifier: ViewModifier {
    @StateObject private var viewModel = ViewModel()
    @State private var widgetOffset: CGSize = .zero
    @State private var widgetPosition: CGPoint = CGPoint(x: 200, y: 100)
    let fcmToken: String?
    /// Overrides `AWLDebugConfig.triggers`; only set by the deprecated `showDebugToolEvents` parameter.
    let triggers: Set<AWLDebugTrigger>?
    let customView: (() -> any View)?

    public func body(content: Content) -> some View {
        content
            .applyFontSize(viewModel.preferredFontSize.sizeCategory)
            .onChange(of: viewModel.preferredColorScheme) { scheme in
                DebugPanelPresenter.shared.applyAppearance(scheme)
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
            .onAppear {
                let presenter = DebugPanelPresenter.shared
                if let triggers {
                    presenter.triggers = triggers
                }
                presenter.content.fcmToken = fcmToken
                presenter.content.customView = customView
                // On the window rather than this view, so taps also count inside sheets and full-screen covers.
                presenter.installInActiveScene()
                presenter.applyAppearance(viewModel.preferredColorScheme)
                VersionOverlayPresenter.shared.update()
            }
            .onChange(of: fcmToken) { fcmToken in
                DebugPanelPresenter.shared.content.fcmToken = fcmToken
            }
    }
}

extension View {
    @ViewBuilder
    func applyFontSize(_ size: ContentSizeCategory?) -> some View {
        if let size {
            self.environment(\.sizeCategory, size)
        } else {
            self
        }
    }
}

extension View {
    /// Adds the debug panel. It opens on `AWLDebugConfig.triggers` or with `AWLDebugTool.open()`.
    public func includeDebugTool(fcmToken: String? = nil,
                                 customView: (() -> any View)? = nil) -> some View {
        modifier(DebugToolViewModifier(fcmToken: fcmToken, triggers: nil, customView: customView))
    }

    @available(*, deprecated, message: "Set AWLDebugConfig.triggers; .threeTaps is .tripleTap, .userDidTakeScreenshot is .screenshot")
    public func includeDebugTool(fcmToken: String? = nil,
                                 showDebugToolEvents: [DebugToolViewModifier.ShowDebugToolEvents],
                                 customView: (() -> any View)? = nil) -> some View {
        modifier(DebugToolViewModifier(fcmToken: fcmToken, triggers: Set(showDebugToolEvents.map(\.trigger)), customView: customView))
    }
}
