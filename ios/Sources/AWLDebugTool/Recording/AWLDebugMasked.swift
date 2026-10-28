import SwiftUI
import UIKit

private var maskedKey: UInt8 = 0

public extension UIView {
    /// Covers this view with a black rectangle in screen recordings. Secure text fields are always covered.
    ///
    /// Store builds do not link the SDK, so wrap the call in the app, e.g. in an extension compiled with `#if AWL_DEBUG`.
    var awlDebugMasked: Bool {
        get { objc_getAssociatedObject(self, &maskedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &maskedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

public extension View {
    /// Covers this view with a black rectangle in screen recordings. `SecureField` is always covered.
    ///
    /// Store builds do not link the SDK, so wrap the call in the app, e.g. in a `View` extension compiled with `#if AWL_DEBUG`.
    func awlDebugMasked() -> some View {
        overlay(MaskMarker().allowsHitTesting(false).accessibilityHidden(true))
    }
}

/// An empty UIKit view with the frame of the masked SwiftUI view, found by the recorder like any masked `UIView`.
private struct MaskMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.awlDebugMasked = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
