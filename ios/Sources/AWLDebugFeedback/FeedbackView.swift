//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import SwiftUI

enum FeedbackOutcome {
    case cancelled
    case sent
    case queued
}

/// Mark up the screenshot, describe the finding, send.
struct FeedbackView: View {
    @ObservedObject var session: FeedbackSession
    @ObservedObject var queue = FeedbackQueueRunner.shared
    let onClose: (FeedbackOutcome) -> Void
    @FocusState private var isTextFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScreenshotMarkup(session: session, isKeyboardUp: isTextFocused, dismissKeyboard: dismissKeyboard)
                DescriptionField(session: session, isFocused: $isTextFocused)
                if session.canAttachLogs {
                    Toggle("Attach logs", isOn: $session.attachLogs)
                        .font(.subheadline)
                        .disabled(session.phase == .sending || session.isFinished)
                }
                if case let .failed(message) = session.phase {
                    FailureRow(message: message, retry: send)
                }
                if queue.pendingCount > 0 {
                    Text("\(queue.pendingCount) pending")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            // Behind everything else, so it only catches taps that no control handles.
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissKeyboard)
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .interactiveDismissDisabled()
        .onChange(of: session.phase) { phase in
            switch phase {
            case .sent:
                onClose(.sent)
            case .queued:
                onClose(.queued)
            case .editing, .sending, .failed:
                break
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: cancel)
                .disabled(session.phase == .sending || session.isFinished)
        }
        ToolbarItem(placement: .confirmationAction) {
            if session.phase == .sending {
                ProgressView()
            } else {
                Button("Send", action: send)
                    .disabled(!session.canSend)
            }
        }
    }

    private func send() {
        dismissKeyboard()
        Task { await session.send() }
    }

    private func cancel() {
        session.discard()
        onClose(.cancelled)
    }

    private func dismissKeyboard() {
        isTextFocused = false
    }
}

private struct ScreenshotMarkup: View {
    let session: FeedbackSession
    let isKeyboardUp: Bool
    let dismissKeyboard: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(uiImage: session.screenshot)
                .resizable()
                .scaledToFit()
                .overlay {
                    MarkupLayer(session: session, isKeyboardUp: isKeyboardUp, dismissKeyboard: dismissKeyboard)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(uiColor: .separator))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Screenshot. Draw on it to mark the issue.")

            MarkupToolbar(session: session)
        }
        // Picking a tool or colour means drawing comes next, so the keyboard goes too.
        .simultaneousGesture(TapGesture().onEnded(dismissKeyboard))
    }
}

private struct DescriptionField: View {
    @ObservedObject var session: FeedbackSession
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                TextEditor(text: $session.text)
                    .focused(isFocused)
                    .frame(height: 96)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        if session.text.isEmpty {
                            Text("Describe the issue")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    .disabled(session.phase == .sending)
                    .accessibilityLabel("Description")

                MicButton(session: session)
            }
            HStack {
                if session.dictation.isRecording {
                    Label("Listening…", systemImage: "waveform")
                        .foregroundStyle(.red)
                } else if let problem = session.dictation.problem {
                    Text(problem)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(session.text.count)/\(FeedbackSession.maxTextLength)")
                    .foregroundStyle(session.text.count > FeedbackSession.maxTextLength ? .red : .secondary)
                    .monospacedDigit()
            }
            .font(.caption)
        }
    }
}

private struct MicButton: View {
    @ObservedObject var session: FeedbackSession

    var body: some View {
        Button {
            Task { await session.toggleDictation() }
        } label: {
            Image(systemName: session.dictation.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 36))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(session.dictation.isRecording ? .red : .accentColor)
                .frame(minWidth: 44, minHeight: 44)
        }
        .disabled(session.phase == .sending || session.isFinished)
        .accessibilityLabel(session.dictation.isRecording ? "Stop dictation" : "Dictate")
    }
}

private struct FailureRow: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.footnote)
            Spacer()
            Button("Retry", action: retry)
                .font(.footnote.bold())
        }
        .padding(10)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}
