//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import UIKit

enum ScreenshotRenderer {
    static let maxJPEGBytes = 5 * 1024 * 1024
    private static let jpegQuality: CGFloat = 0.85

    /// Draws every visible window of the scene bottom-up, so sheets, alerts and overlays of the
    /// app end up in the picture, but none of the given excluded windows.
    @MainActor
    static func capture(scene: UIWindowScene, excluding excluded: [UIWindow] = []) -> UIImage? {
        let windows = scene.windows
            .filter { !$0.isHidden && $0.alpha > 0 && !excluded.contains($0) }
            .sorted { $0.windowLevel < $1.windowLevel }
        guard let reference = scene.keyWindow ?? windows.first else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat(for: reference.traitCollection)
        return UIGraphicsImageRenderer(bounds: reference.bounds, format: format).image { _ in
            for window in windows {
                window.drawHierarchy(in: window.frame, afterScreenUpdates: false)
            }
        }
    }

    /// Burns the marks into the screenshot at its full resolution.
    static func flatten(screenshot: UIImage, marks: [MarkupMark]) -> UIImage {
        guard !marks.isEmpty else {
            return screenshot
        }
        let imageRect = CGRect(origin: .zero, size: screenshot.size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = screenshot.scale
        return UIGraphicsImageRenderer(bounds: imageRect, format: format).image { context in
            screenshot.draw(in: imageRect)
            MarkupGeometry.draw(marks, in: context.cgContext, size: imageRect.size)
        }
    }

    /// JPEG at fixed quality, downscaled until it fits the service's upload limit.
    static func jpegData(from image: UIImage) -> Data? {
        var current = image
        for _ in 0 ..< 6 {
            guard let data = current.jpegData(compressionQuality: jpegQuality) else {
                return nil
            }
            if data.count <= maxJPEGBytes {
                return data
            }
            current = downscaled(current, by: 0.75)
        }
        return nil
    }

    private static func downscaled(_ image: UIImage, by factor: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
