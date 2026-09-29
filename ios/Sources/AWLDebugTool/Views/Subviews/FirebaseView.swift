//
//  FirebaseView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct FirebaseView: View {
    
    var body: some View {
        Section {
            ProprietaryActionButton(text: LS.Actions.simulateCrash,
                                    subtext:  LS.Actions.explicitCrash,
                                    icon: .crash,
                                    iconColor: IconColor.action,
                                    action: simulateCrashExplicitly)

            ProprietaryActionButton(text: LS.Actions.simulateCrash,
                                    subtext:  LS.Actions.implicitCrash,
                                    icon: .crash,
                                    iconColor: IconColor.action,
                                    action: simulateCrashImplicitly)
        } header: {
            Text(LS.Headers.firebaseActions)
        }
    }
    
    func simulateCrashExplicitly() {
        fatalError(LS.Strings.fatalErrorMsg)
    }

    func simulateCrashImplicitly() {
        var testArray: [Int] = []
        _ = testArray.removeFirst()
        _ = 1 / testArray.count
    }
}

#Preview {
    FirebaseView()
}
