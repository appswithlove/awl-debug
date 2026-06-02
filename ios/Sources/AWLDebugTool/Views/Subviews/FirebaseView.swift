//
//  FirebaseView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct FirebaseView: View {
    let simulateCrashExplicitly: () -> Void
    let simulateCrashImplicitly: () -> Void
    
    var body: some View {
        Section {
            ProprietaryActionButton(text: LS.Actions.simulateCrash,
                                    subtext:  LS.Actions.explicitCrash,
                                    iconName: Constants.Image.crash,
                                    iconColor: IconColor.action,
                                    action: simulateCrashExplicitly)

            ProprietaryActionButton(text: LS.Actions.simulateCrash,
                                    subtext:  LS.Actions.implicitCrash,
                                    iconName: Constants.Image.crash,
                                    iconColor: IconColor.action,
                                    action: simulateCrashImplicitly)
        } header: {
            Text(LS.Headers.firebaseActions)
        }
    }
}

#Preview {
    FirebaseView(simulateCrashExplicitly: {}, simulateCrashImplicitly: {})
}
