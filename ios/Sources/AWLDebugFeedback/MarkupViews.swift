//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import SwiftUI

/// Draws the marks over the screenshot and turns drags into new ones. Sized exactly like the
/// displayed image, so unit coordinates map straight onto the screenshot.
struct MarkupLayer: View {
    @ObservedObject var session: FeedbackSession
    /// While the keyboard is up, a touch on the image only dismisses it and draws nothing.
    let isKeyboardUp: Bool
    let dismissKeyboard: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let marks = session.marks + (session.pendingMark.map { [$0] } ?? [])
                let style = StrokeStyle(
                    lineWidth: MarkupGeometry.lineWidth(for: size),
                    lineCap: .round,
                    lineJoin: .round
                )
                for mark in marks {
                    let path = Path(MarkupGeometry.path(for: mark, in: size))
                    let shading = GraphicsContext.Shading.color(Color(uiColor: mark.color.uiColor))
                    if mark.isFilled {
                        context.fill(path, with: shading)
                    } else {
                        context.stroke(path, with: shading, style: style)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(drag(in: proxy.size), including: session.phase == .editing && !isKeyboardUp ? .all : .none)
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in dismissKeyboard() }, including: isKeyboardUp ? .all : .none)
        }
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard size.width > 0, size.height > 0 else {
                    return
                }
                session.dragMark(to: CGPoint(x: value.location.x / size.width, y: value.location.y / size.height))
            }
            .onEnded { _ in
                session.endMark()
            }
    }
}

/// Tools, colours, undo and clear in one column beside the screenshot, within thumb reach.
struct MarkupToolbar: View {
    @ObservedObject var session: FeedbackSession

    var body: some View {
        // Bottom-aligned for thumb reach. Scrolls only when the height is too small (keyboard up,
        // small phone), starting at the top so the selected tool stays in view.
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                controls
            }
            ScrollView(.vertical) {
                controls
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(width: 48)
        .disabled(session.phase != .editing)
    }

    /// No spacing between the 44 pt targets, so all ten fit beside the screenshot on a 6.3" phone.
    private var controls: some View {
        VStack(spacing: 0) {
            ForEach(MarkupTool.allCases, id: \.self) { tool in
                ToolButton(tool: tool, isSelected: session.tool == tool) {
                    session.tool = tool
                }
            }
            Divider().frame(width: 32).padding(.vertical, 4)
            ForEach(MarkupColor.allCases, id: \.self) { color in
                // Redact is always black; the colours apply to Pen and Arrow only.
                ColorSwatch(color: color, isSelected: session.color == color) {
                    session.color = color
                }
                .disabled(session.tool == .redact)
            }
            Divider().frame(width: 32).padding(.vertical, 4)
            IconButton(title: "Undo", systemImage: "arrow.uturn.backward", action: session.undoLastMark)
                .disabled(!session.canUndo)
            IconButton(title: "Clear", systemImage: "trash", action: session.clearMarks)
                .foregroundStyle(.red)
                .disabled(!session.canUndo)
        }
        .padding(.vertical, 4)
    }
}

private struct ToolButton: View {
    let tool: MarkupTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.systemImage)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(
                    isSelected ? AnyShapeStyle(.tint.opacity(0.2)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .accessibilityLabel(tool.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension MarkupTool {
    var systemImage: String {
        switch self {
        case .pen: "scribble"
        case .arrow: "arrow.up.right"
        case .redact: "rectangle.fill"
        }
    }
}

private struct ColorSwatch: View {
    let color: MarkupColor
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(uiColor: color.uiColor))
                .frame(width: 26, height: 26)
                .overlay {
                    Circle().stroke(Color(uiColor: .separator), lineWidth: 1)
                }
                .padding(3)
                .overlay {
                    if isSelected {
                        Circle().stroke(.primary, lineWidth: 2.5)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.38)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct IconButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(title)
    }
}
