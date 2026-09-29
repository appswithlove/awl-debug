//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import CoreGraphics
import UIKit

enum MarkupTool: CaseIterable {
    case pen
    case arrow
}

enum MarkupColor: CaseIterable {
    case red
    case yellow
    case green
    case blue
    case black

    var name: String {
        switch self {
        case .red: "Red"
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .black: "Black"
        }
    }

    /// Fixed values rather than dynamic system colours, so the burnt-in marks match the preview.
    var uiColor: UIColor {
        switch self {
        case .red: UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
        case .yellow: UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
        case .green: UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
        case .blue: UIColor(red: 0, green: 0.48, blue: 1, alpha: 1)
        case .black: .black
        }
    }
}

/// One mark on the screenshot. Points are in unit coordinates (0...1 of the image's width and
/// height), so marks stay put when the on-screen canvas changes size and burn in at any resolution.
struct MarkupMark: Equatable {
    enum Shape: Equatable {
        case stroke([CGPoint])
        case arrow(start: CGPoint, end: CGPoint)
    }

    var shape: Shape
    let color: MarkupColor
}

enum MarkupGeometry {
    private static let lineWidthFraction: CGFloat = 0.012
    private static let arrowHeadAngle: CGFloat = .pi / 6

    static func lineWidth(for size: CGSize) -> CGFloat {
        max(2, size.width * lineWidthFraction)
    }

    static func arrowHeadLength(for size: CGSize) -> CGFloat {
        lineWidth(for: size) * 4
    }

    /// The two outer points of an open arrowhead at `end`.
    static func arrowHead(from start: CGPoint, to end: CGPoint, length: CGFloat) -> (CGPoint, CGPoint) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        func point(_ offset: CGFloat) -> CGPoint {
            CGPoint(
                x: end.x - length * cos(angle + offset),
                y: end.y - length * sin(angle + offset)
            )
        }
        return (point(arrowHeadAngle), point(-arrowHeadAngle))
    }

    /// The mark's outline in a space of the given size, ready to be stroked with `lineWidth(for:)`.
    static func path(for mark: MarkupMark, in size: CGSize) -> CGPath {
        func scaled(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * size.width, y: point.y * size.height)
        }
        let path = CGMutablePath()
        switch mark.shape {
        case let .stroke(points):
            guard let first = points.first else {
                break
            }
            // A tap without movement still leaves a visible dot.
            path.addLines(between: points.count == 1 ? [scaled(first), scaled(first)] : points.map(scaled))
        case let .arrow(start, end):
            let from = scaled(start)
            let to = scaled(end)
            let (left, right) = arrowHead(from: from, to: to, length: arrowHeadLength(for: size))
            path.move(to: from)
            path.addLine(to: to)
            path.move(to: left)
            path.addLine(to: to)
            path.addLine(to: right)
        }
        return path
    }

    static func stroke(_ marks: [MarkupMark], in context: CGContext, size: CGSize) {
        context.saveGState()
        context.setLineWidth(lineWidth(for: size))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for mark in marks {
            context.addPath(path(for: mark, in: size))
            context.setStrokeColor(mark.color.uiColor.cgColor)
            context.strokePath()
        }
        context.restoreGState()
    }
}
