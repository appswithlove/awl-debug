//
//  PermissionsView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct PermissionsView: View {
    let statuses: [PermissionRequestType: RequestPermissionStatus]
    let checkIfPermissionRequestTypeExistsInApp: (PermissionRequestType) -> Bool
    let request: (PermissionRequestType) async -> ()
    let openAppSettings: () -> Void
    
    var body: some View {
        Section {
            VStack {
                ForEach(PermissionRequestType.allCases) { type in
                    PermissionItem(status: statuses[type] ?? RequestPermissionStatus.notDetermined,
                                   type: type,
                                   available: checkIfPermissionRequestTypeExistsInApp(type),
                                   openSystemPermissionRequest: { Task { await request(type) }},
                                   openSettingsAction: { openAppSettings() })
                }
            }
            
            ProprietaryActionButton(text: LS.Actions.openAppSettings,
                                    icon: .gear,
                                    iconColor: IconColor.action,
                                    action: { openAppSettings() })
        } header: {
            Text(LS.Headers.permissions)
        }
    }
}

#Preview {
    PermissionsView(statuses: [:],
                    checkIfPermissionRequestTypeExistsInApp: { _ in true},
                    request: { _ in  },
                    openAppSettings: {})
}
