//
//  PermissionsView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct PermissionsView: View {
    @ObservedObject var manager: PermissionsManager

    var body: some View {
        Section {
            if manager.declaredTypes.isEmpty {
                Text(LS.Permissions.empty)
                    .foregroundStyle(.secondary)
            }
            ForEach(manager.declaredTypes) { type in
                PermissionItem(status: manager.statuses[type], type: type)
            }

            ProprietaryActionButton(text: LS.Actions.openAppSettings,
                                    icon: .gear,
                                    iconColor: IconColor.action,
                                    action: manager.openAppSettings)
        } header: {
            Text(LS.Headers.permissions)
        }
        .task {
            await manager.refreshStatuses()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await manager.refreshStatuses() }
        }
    }
}
