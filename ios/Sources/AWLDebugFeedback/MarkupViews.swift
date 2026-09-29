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
                    context.stroke(
                        Path(MarkupGeometry.path(for: mark, in: size)),
                        with: .color(Color(uiColor: mark.color.uiColor)),
                        style: style
                    )
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
        // Bottom-aligned for thumb reach; scrolls only when the keyboard leaves too little height.
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
            .bottomScrollAnchor()
        }
        .frame(width: 48)
        .disabled(session.phase != .editing)
    }

    private var controls: some View {
        VStack(spacing: 4) {
            ForEach(MarkupTool.allCases, id: \.self) { tool in
                ToolButton(tool: tool, isSelected: session.tool == tool) {
                    session.tool = tool
                }
            }
            Divider().frame(width: 32).padding(.vertical, 4)
            ForEach(MarkupColor.allCases, id: \.self) { color in
                ColorSwatch(color: color, isSelected: session.color == color) {
                    session.color = color
                }
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
            Image(systemName: tool == .pen ? "scribble" : "arrow.up.right")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(
                    isSelected ? AnyShapeStyle(.tint.opacity(0.2)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .accessibilityLabel(tool == .pen ? "Pen" : "Arrow")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ColorSwatch: View {
    let color: MarkupColor
    let isSelected: Bool
    let action: () -> Void

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

private extension View {
    @ViewBuilder
    func bottomScrollAnchor() -> some View {
        if #available(iOS 17, *) {
            defaultScrollAnchor(.bottom)
        } else {
            self
        }
    }
}
