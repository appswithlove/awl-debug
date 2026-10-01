//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import SwiftUI

enum FeedbackField: Hashable {
    case description
    case reporterName
    case reporterEmail
}

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
    @FocusState private var focusedField: FeedbackField?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScreenshotMarkup(session: session, isKeyboardUp: focusedField != nil, dismissKeyboard: dismissKeyboard)
                DescriptionField(session: session, focusedField: $focusedField)
                ReporterRow(session: session, focusedField: $focusedField)
                if session.canAttachLogs {
                    Toggle("Attach logs", isOn: $session.attachLogs)
                        .font(.subheadline)
                        .disabled(session.phase == .sending || session.isFinished)
                }
                if session.canAttachRecording {
                    Toggle("Attach last recording", isOn: $session.attachRecording)
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
        focusedField = nil
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
                .accessibilityLabel("Screenshot. Draw to mark the problem.")

            MarkupToolbar(session: session)
        }
        // Picking a tool or colour means drawing comes next, so the keyboard goes too.
        .simultaneousGesture(TapGesture().onEnded(dismissKeyboard))
    }
}

private struct DescriptionField: View {
    @ObservedObject var session: FeedbackSession
    let focusedField: FocusState<FeedbackField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                TextEditor(text: $session.text)
                    .focused(focusedField, equals: .description)
                    .frame(height: 96)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        if session.text.isEmpty {
                            Text("What happened?")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    .disabled(session.phase == .sending)
                    .accessibilityLabel("What happened?")

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
                // Verbatim: a localized key would group the digits ("5'000"); the spec and Android show "{n}/5000".
                Text(verbatim: "\(session.textLength)/\(FeedbackSession.maxTextLength)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.caption)
        }
    }
}

/// Asks for name (required) and email (optional) until a first report is sent, then "Sent as {name}".
private struct ReporterRow: View {
    @ObservedObject var session: FeedbackSession
    let focusedField: FocusState<FeedbackField?>.Binding

    var body: some View {
        Group {
            if session.isEditingReporter {
                HStack(spacing: 8) {
                    TextField("Your name", text: $session.reporterName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused(focusedField, equals: .reporterName)
                        .onSubmit { focusedField.wrappedValue = .reporterEmail }
                    TextField("Email (optional)", text: $session.reporterEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused(focusedField, equals: .reporterEmail)
                        .foregroundStyle(session.isReporterEmailValid ? Color.primary : Color.red)
                }
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("Sent as \(session.reporterName.trimmed)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Change", action: session.changeReporter)
                }
                .font(.subheadline)
            }
        }
        .disabled(session.phase == .sending || session.isFinished)
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
