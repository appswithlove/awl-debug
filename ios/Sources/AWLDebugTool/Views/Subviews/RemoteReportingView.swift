//
//  RemoteReportingView.swift
//  AWLDebugTool
//

import SwiftUI
import UIKit

/// State of the "Remote reporting" panel row, fed by `RemoteReporting` on the main thread.
final class RemoteReportingPanelState: ObservableObject {
    @Published var status = RemoteReporting.Status.notConfigured
    @Published var snapshot = RemoteReporter.Snapshot()
}

/// Panel row under App-Info: on/off, last flush, pending batches, error, "Flush now", the
/// "Send session data" switch and the session ID to look it up in the dashboard. Hidden without config.
struct RemoteReportingView: View {
    @ObservedObject var state: RemoteReportingPanelState
    @State private var isSendingEnabled = RemoteReporting.isSendingEnabled
    @State private var didCopy = false

    private var isOn: Bool {
        state.status == .recording && isSendingEnabled && !state.snapshot.upload.isStopped
    }

    var body: some View {
        if state.status != .notConfigured {
            Section {
                LabeledContent(LS.Reporting.title, value: isOn ? LS.Reporting.on : LS.Reporting.off)
                if let problem = problemText {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(state.snapshot.upload.isStopped || state.status == .storeBuild ? .red : .orange)
                }
                if state.status == .recording {
                    Toggle(LS.Reporting.toggle, isOn: $isSendingEnabled)
                        .onChange(of: isSendingEnabled) { enabled in
                            RemoteReporting.shared.setSendingEnabled(enabled)
                        }
                    if let lastSentAt = state.snapshot.upload.lastSentAt {
                        Text(LS.Reporting.lastFlush(lastSentAt.formatted(date: .omitted, time: .standard)))
                    }
                    Text(LS.Reporting.pending(state.snapshot.upload.pendingCount))
                    if let sessionId = state.snapshot.sessionId {
                        Button {
                            UIPasteboard.general.string = sessionId
                            didCopy = true
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(didCopy ? LS.Reporting.copied : LS.Reporting.sessionId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(sessionId)
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                            }
                        }
                        .onChange(of: sessionId) { _ in didCopy = false }
                    }
                    Button(LS.Reporting.flushNow) {
                        AWLDebugTool.flushReports()
                    }
                    .disabled(!isOn)
                }
            }
        }
    }

    private var problemText: String? {
        if state.status == .storeBuild {
            return LS.Reporting.disabledStore
        }
        switch state.snapshot.upload.problem {
        case .unauthorized: return LS.Reporting.unauthorized
        case .disabledByServer: return LS.Reporting.disabledByServer
        case .rejected(let status): return LS.Reporting.rejected(status)
        case nil: return nil
        }
    }
}
