//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

@testable import AWLDebugFeedback
import Testing
import UIKit

struct MarkupTests {
    @Test
    func arrowHeadPointsBackFromTheTip() {
        let (left, right) = MarkupGeometry.arrowHead(from: .zero, to: CGPoint(x: 100, y: 0), length: 10)

        #expect(abs(left.x - 91.34) < 0.01)
        #expect(abs(right.x - 91.34) < 0.01)
        #expect(abs(left.y + 5) < 0.01)
        #expect(abs(right.y - 5) < 0.01)
    }

    @Test
    func pathScalesUnitCoordinatesToTheTargetSize() {
        let mark = MarkupMark(shape: .stroke([CGPoint(x: 0.25, y: 0.5), CGPoint(x: 0.75, y: 0.5)]), color: .red)

        let bounds = MarkupGeometry.path(for: mark, in: CGSize(width: 400, height: 800)).boundingBoxOfPath

        #expect(bounds == CGRect(x: 100, y: 400, width: 200, height: 0))
    }

    @Test
    func flattenWithoutMarksReturnsTheScreenshotUnchanged() {
        let screenshot = Self.whiteImage()

        #expect(ScreenshotRenderer.flatten(screenshot: screenshot, marks: []) === screenshot)
    }

    @Test
    func flattenBurnsStrokesAndArrowsIntoTheImage() throws {
        let marks = [
            MarkupMark(shape: .stroke([CGPoint(x: 0.1, y: 0.25), CGPoint(x: 0.9, y: 0.25)]), color: .red),
            MarkupMark(shape: .arrow(start: CGPoint(x: 0.1, y: 0.75), end: CGPoint(x: 0.9, y: 0.75)), color: .blue)
        ]

        let image = ScreenshotRenderer.flatten(screenshot: Self.whiteImage(), marks: marks)

        #expect(image.size == CGSize(width: 100, height: 200))
        let red = try Self.pixel(of: image, x: 50, y: 50)
        let blue = try Self.pixel(of: image, x: 50, y: 150)
        let untouched = try Self.pixel(of: image, x: 50, y: 100)
        #expect(red.red > 200 && red.blue < 100)
        #expect(blue.blue > 200 && blue.red < 50)
        #expect(untouched == Pixel(red: 255, green: 255, blue: 255))
    }

    @MainActor
    @Test
    func undoRemovesTheLastMarkAcrossTools() {
        let session = FeedbackSession(screenshot: Self.whiteImage(), config: Self.config)
        session.dragMark(to: CGPoint(x: 0.1, y: 0.1))
        session.dragMark(to: CGPoint(x: 0.2, y: 0.2))
        session.endMark()
        session.tool = .arrow
        session.color = .blue
        session.dragMark(to: CGPoint(x: 0.3, y: 0.3))
        session.dragMark(to: CGPoint(x: 0.8, y: 0.8))
        session.endMark()

        #expect(session.marks.map(\.color) == [.red, .blue])
        session.undoLastMark()
        #expect(session.marks.map(\.color) == [.red])
    }

    @MainActor
    @Test
    func tapWithArrowToolAddsNoMark() {
        let session = FeedbackSession(screenshot: Self.whiteImage(), config: Self.config)
        session.tool = .arrow
        session.dragMark(to: CGPoint(x: 0.5, y: 0.5))
        session.endMark()

        #expect(session.marks.isEmpty)
    }

    private struct Pixel: Equatable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
    }

    private static let config = FeedbackConfig(
        endpoint: URL(filePath: "/"),
        appKey: "key",
        appVersion: "1",
        buildNumber: "1",
        environment: "test"
    )

    private static func whiteImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
        }
    }

    private static func pixel(of image: UIImage, x: Int, y: Int) throws -> Pixel {
        let cgImage = try #require(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &bytes,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let scale = image.scale
        context.draw(cgImage, in: CGRect(
            x: -CGFloat(x) * scale,
            y: -CGFloat(cgImage.height) + CGFloat(y + 1) * scale,
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        ))
        return Pixel(red: bytes[0], green: bytes[1], blue: bytes[2])
    }
}
