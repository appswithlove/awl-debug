//
//  UserDefaultsView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct UserDefaultsView: View {
    let isShowingDeleteUserDefaults: Binding<Bool>
    let showDeleteUserDefaultsAlert: () -> Void
    
    var body: some View {
        Section {
            ProprietaryActionButton(text: LS.Actions.clearAppUserDefaults,
                                    icon: .clear,
                                    iconColor: IconColor.deletion,
                                    action: { showDeleteUserDefaultsAlert() })
        } header: {
            Text(LS.Headers.userDefaults)
        }
        .destructiveAlertViewModifier(isShowingAlert: isShowingDeleteUserDefaults,
                                      title: LS.Alert.deleteUDTitle,
                                      message: LS.Alert.deleteUDMessage,
                                      action: { UserDefaults.standard.clearAppUserDefaults() })
    }
}

#Preview {
    UserDefaultsView(isShowingDeleteUserDefaults: .constant(true),
                     showDeleteUserDefaultsAlert: {})
}
