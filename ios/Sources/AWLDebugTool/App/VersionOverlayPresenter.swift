import SwiftUI
import UIKit

/// "AWL <version> (<build>)" in a window of its own above the app, so it also shows over sheets.
/// The window never takes touches.
@MainActor
final class VersionOverlayPresenter {
    static let shared = VersionOverlayPresenter()

    /// `AWLDebugConfig.showVersionOverlay`; `false` hides the overlay and its switch.
    var isAvailable = true
    private var window: UIWindow?

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Constants.UserDefaultsKey.versionOverlayVisible) as? Bool ?? true
    }

    static var text: String {
        let info = Bundle.main.infoDictionary
        return "AWL \(info?["CFBundleShortVersionString"] as? String ?? "") (\(info?["CFBundleVersion"] as? String ?? ""))"
    }

    func update(in scene: UIWindowScene? = nil) {
        guard isAvailable, Self.isEnabled else {
            window?.isHidden = true
            window = nil
            return
        }
        guard window == nil, let scene = scene ?? Self.activeScene() else {
            return
        }
        // Not tagged as one of the SDK's windows: like the app, it is in screen recordings and screenshots of extensions,
        // so they show which build it was.
        let window = PassthroughWindow(windowScene: scene)
        // Above the app and its presentations, below the debug panel and the SDK's other windows.
        window.windowLevel = .statusBar
        window.isUserInteractionEnabled = false
        let host = UIHostingController(rootView: VersionOverlayView())
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

private struct VersionOverlayView: View {
    @ObservedObject var screenRecorder = AWLDebugTool.shared.screenRecorder

    var body: some View {
        VStack {
            HStack(spacing: 4) {
                if screenRecorder.isOn {
                    // Shows testers that the screen is being recorded.
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                }
                Text(VersionOverlayPresenter.text)
                    .font(.system(size: 8))
                    .foregroundStyle(Color(UIColor.label))
                    .padding(.horizontal, 2)
                    .background(Color(UIColor.systemBackground).opacity(0.7), ignoresSafeAreaEdges: [])
                Spacer()
            }
            Spacer()
        }
        .padding(.leading, 8)
        .accessibilityHidden(true)
    }
}
