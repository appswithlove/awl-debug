//
//  FCMPushTokenView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct FCMPushTokenView: View {
    let fcmToken: String?
    
    var body: some View {
        Section {
            Text("\(fcmToken ?? LS.Strings.unknownValue)")
        } header: {
            Text(LS.Headers.fcm)
        }
    }
}

#Preview {
    FCMPushTokenView(fcmToken: "q1w2e3r4t5")
}
