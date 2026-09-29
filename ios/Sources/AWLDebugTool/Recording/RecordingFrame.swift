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
    /// `accessibilityIdentifier` of the SDK's own windows (panel, feedback, overlays); they are never recorded.
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
    @MainActor
    static func capture(windows: [UIWindow], bounds: CGRect, date: Date = Date()) -> RecordingFrame {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
            for window in windows {
                window.drawHierarchy(in: window.frame, afterScreenUpdates: false)
            }
        }
        let masks = windows.flatMap { window in
            maskedRects(in: window).map { $0.offsetBy(dx: window.frame.minX, dy: window.frame.minY) }
        }
        return RecordingFrame(image: image, masks: masks, date: date)
    }

    /// Secure text fields (also behind `SecureField`) and views marked `awlDebugMasked`, in window coordinates.
    /// A mask is dropped when an opaque view drawn later covers it completely, e.g. a sheet over a masked screen.
    @MainActor
    static func maskedRects(in window: UIWindow) -> [CGRect] {
        var rects: [CGRect] = []
        func visit(_ view: UIView) {
            guard !view.isHidden, view.alpha > 0.01 else {
                return
            }
            let frame = view.convert(view.bounds, to: window)
            if view.awlDebugMasked || (view as? UITextField)?.isSecureTextEntry == true {
                if !frame.isEmpty {
                    rects.append(frame)
                }
                return
            }
            if !rects.isEmpty, view.alpha >= 1, let background = view.backgroundColor, background.cgColor.alpha >= 1 {
                rects.removeAll { frame.contains($0) }
            }
            view.subviews.forEach(visit)
        }
        visit(window)
        return rects
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
