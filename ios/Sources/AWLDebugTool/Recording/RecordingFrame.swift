import UIKit

/// One recorded frame: the drawn app windows plus what the encoder adds in the background.
struct RecordingFrame {
    let image: UIImage
    /// Rectangles covered in black, in the image's coordinates.
    let masks: [CGRect]
    let date: Date
}

enum RecordingTouchPhase {
    case began, moved, ended
}

struct RecordingTouch {
    let location: CGPoint
    let phase: RecordingTouchPhase
}

enum RecordingFrameRenderer {
    /// `accessibilityIdentifier` of the SDK's own windows (panel, feedback); they are never recorded. The version overlay
    /// is recorded, so the frames show which build it was.
    static let sdkWindowIdentifier = "AWLDebugWindow"
    static let jpegQuality: CGFloat = 0.6

    /// Visible windows of the scene that belong to the app, bottom-up; without the SDK's and the keyboard's windows.
    @MainActor
    static func appWindows(of scene: UIWindowScene) -> [UIWindow] {
        scene.windows
            .filter { !$0.isHidden && $0.alpha > 0.01 && isAppWindow($0) }
            .sorted { $0.windowLevel < $1.windowLevel }
    }

    static func isAppWindow(_ window: UIWindow) -> Bool {
        guard window.accessibilityIdentifier != sdkWindowIdentifier else {
            return false
        }
        let name = NSStringFromClass(type(of: window))
        return !name.contains("Keyboard") && !name.contains("TextEffects")
    }

    /// Draws the windows at scale 1 and finds the masked areas of this very state of the screen. Main thread only.
    /// `nil` while a masked view moves, because then the mask cannot be placed where the view is drawn.
    @MainActor
    static func capture(windows: [UIWindow], bounds: CGRect, date: Date = Date()) -> RecordingFrame? {
        var masks: [CGRect] = []
        for window in windows {
            guard let rects = maskedRects(in: window) else {
                return nil
            }
            masks += rects.map { $0.offsetBy(dx: window.frame.minX, dy: window.frame.minY) }
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // Not opaque: in an opaque context a window drawn on top (the version overlay) blacks out the windows below.
        format.opaque = false
        let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
            for window in windows {
                window.drawHierarchy(in: window.frame, afterScreenUpdates: false)
            }
        }
        return RecordingFrame(image: image, masks: masks, date: date)
    }

    /// Secure text fields (also behind `SecureField`) and views marked `awlDebugMasked`, in window coordinates.
    /// A mask is dropped when an opaque view drawn later covers it completely, e.g. a sheet over a masked screen.
    ///
    /// While a view animates, `drawHierarchy` draws it somewhere between its start and its model frame, and the
    /// presentation layer does not always say where (system sheets pace their animations). So a moving view never
    /// covers a mask, and a moving masked view gives `nil`: the frame is skipped.
    @MainActor
    static func maskedRects(in window: UIWindow) -> [CGRect]? {
        var rects: [CGRect] = []
        var isMaskMoving = false
        /// `clip`: what the ancestors let through; `alpha`: theirs multiplied; `canCover`: nothing above moves, is
        /// rotated or has a layer mask; `isMoving`: something above animates.
        func visit(_ view: UIView, clip: CGRect, alpha: CGFloat, canCover: Bool, isMoving: Bool) {
            let isMoving = isMoving || isAnimating(view.layer)
            guard !isMaskMoving, !view.isHidden, view.alpha > 0.01 || isMoving else {
                return
            }
            let frame = view.convert(view.bounds, to: window)
            if view.awlDebugMasked || (view as? UITextField)?.isSecureTextEntry == true {
                isMaskMoving = isMoving
                if !frame.isEmpty {
                    rects.append(frame.integral)
                }
                return
            }
            let alpha = alpha * view.alpha
            let isAxisAligned = isAxisAligned(view.layer.transform)
            let canCover = canCover && !isMoving && isAxisAligned && view.layer.mask == nil
            // Rounded corners let the content below show through, so only the inner part counts.
            let radius = view.layer.cornerRadius
            let visible = frame.intersection(clip).insetBy(dx: radius, dy: radius)
            if !rects.isEmpty, canCover, alpha >= 1, let background = view.backgroundColor, background.cgColor.alpha >= 1 {
                rects.removeAll { visible.contains($0) }
            }
            let childClip = view.clipsToBounds && isAxisAligned ? visible : clip
            for subview in view.subviews {
                visit(subview, clip: childClip, alpha: alpha, canCover: canCover, isMoving: isMoving)
            }
        }
        visit(window, clip: .infinite, alpha: 1, canCover: true, isMoving: false)
        return isMaskMoving ? nil : rects
    }

    /// Whether the layer runs an animation or is shown in another state than its model.
    private static func isAnimating(_ layer: CALayer) -> Bool {
        if layer.animationKeys()?.isEmpty == false {
            return true
        }
        guard let shown = layer.presentation() else {
            return false
        }
        return shown.position != layer.position || shown.bounds != layer.bounds || shown.opacity != layer.opacity
            || !CATransform3DEqualToTransform(shown.transform, layer.transform)
    }

    /// Scaled or moved, but not rotated or skewed, so its frame is exactly where it draws.
    private static func isAxisAligned(_ transform: CATransform3D) -> Bool {
        guard CATransform3DIsAffine(transform) else {
            return false
        }
        let affine = CATransform3DGetAffineTransform(transform)
        return (affine.b == 0 && affine.c == 0) || (affine.a == 0 && affine.d == 0)
    }

    /// Masks, touch circles and JPEG encoding; runs off the main thread.
    static func encode(_ frame: RecordingFrame, touches: [RecordingTouch]) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = frame.image.scale
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: frame.image.size, format: format).image { context in
            frame.image.draw(at: .zero)
            let cg = context.cgContext
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(frame.masks)
            for touch in touches {
                drawCircle(for: touch, in: cg)
            }
        }
        return image.jpegData(compressionQuality: jpegQuality)
    }

    /// Green ring where a touch begins (radius 20), no ring while it moves (15), red ring where it ends (15).
    private static func drawCircle(for touch: RecordingTouch, in cg: CGContext) {
        let radius: CGFloat = touch.phase == .began ? 20 : 15
        let rect = CGRect(x: touch.location.x - radius, y: touch.location.y - radius, width: radius * 2, height: radius * 2)
        cg.setFillColor(UIColor.brown.withAlphaComponent(0.3).cgColor)
        cg.fillEllipse(in: rect)
        let stroke: UIColor?
        switch touch.phase {
        case .began: stroke = .green
        case .moved: stroke = nil
        case .ended: stroke = .red
        }
        if let stroke {
            cg.setStrokeColor(stroke.cgColor)
            cg.setLineWidth(3)
            cg.strokeEllipse(in: rect)
        }
    }
}
