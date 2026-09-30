//
//  FCMPushTokenView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

/// Inline block on the start page. Hidden while the app passes no token, like the other modules without input.
struct FCMPushTokenView: View {
    let fcmToken: String?
    
    var body: some View {
        if let fcmToken {
            Section {
                // Long press selects the token for copying.
                Text(fcmToken)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            } header: {
                Text(LS.Headers.fcm)
            }
        }
    }
}

#Preview {
    Form {
        FCMPushTokenView(fcmToken: "q1w2e3r4t5")
    }
}
