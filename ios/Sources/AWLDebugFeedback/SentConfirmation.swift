//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import SwiftUI
import UIKit

/// The "Feedback sent" (or "Saved…") card, shown over the app after the feedback UI has closed. It lives in a
/// window that lets every touch through, so the app stays usable while it fades out.
@MainActor
final class SentConfirmationPresenter {
    private var window: UIWindow?

    func show(in scene: UIWindowScene, message: String, systemImage: String) {
        window?.isHidden = true
        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        let host = UIHostingController(rootView: SentConfirmation(message: message, systemImage: systemImage) { [weak self, weak window] in
            window?.isHidden = true
            if self?.window === window {
                self?.window = nil
            }
        })
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

private final class PassthroughWindow: UIWindow {
    override func hitTest(_: CGPoint, with _: UIEvent?) -> UIView? {
        nil
    }
}

private struct SentConfirmation: View {
    let message: String
    let systemImage: String
    let onFinished: () -> Void
    @State private var isVisible = false

    var body: some View {
        ZStack {
            if isVisible {
                VStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The announcement already speaks the message; the card itself is never focusable.
        .accessibilityHidden(true)
        .task {
            withAnimation(.easeOut(duration: 0.2)) { isVisible = true }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeIn(duration: 0.3)) { isVisible = false }
            try? await Task.sleep(for: .seconds(0.3))
            onFinished()
        }
    }
}
