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
            ProprietaryActionButton(text: Constants.Actions.clearAppUserDefaults,
                                    iconName: Constants.Image.clear,
                                    iconColor: IconColor.deletion,
                                    action: { showDeleteUserDefaultsAlert() })
        } header: {
            Text(Constants.Headers.userDefaults)
        }
        .destructiveAlertViewModifier(isShowingAlert: isShowingDeleteUserDefaults,
                                      title: Constants.Alert.deleteUDTitle,
                                      message: Constants.Alert.deleteUDMessage,
                                      action: { UserDefaults.standard.clearAppUserDefaults() })
    }
}

#Preview {
    UserDefaultsView(isShowingDeleteUserDefaults: .constant(true),
                     showDeleteUserDefaultsAlert: {})
}
