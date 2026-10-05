//
//  FCMPushTokenView.swift
//  
//

import SwiftUI
import UIKit

/// Start page: the token inline with Copy, or without a token a row that opens how to pass one.
struct FCMPushTokenView: View {
    let fcmToken: String?

    var body: some View {
        if let fcmToken {
            Section {
                // Long press selects the token for copying.
                Text(fcmToken)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = fcmToken
                } label: {
                    Label(LS.Actions.copy, systemImage: "doc.on.doc")
                }
            } header: {
                Text(LS.Headers.fcm)
            }
        } else {
            Section {
                PanelModuleRow(title: LS.Headers.fcm) {
                    Form {
                        Section {
                            SetupHint(title: LS.FCM.notSetup, message: LS.FCM.notSetupMessage,
                                      snippet: LS.FCM.setupSnippet)
                        }
                    }
                    .panelPage(LS.Headers.fcm)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            FCMPushTokenView(fcmToken: "q1w2e3r4t5")
            FCMPushTokenView(fcmToken: nil)
        }
    }
}
