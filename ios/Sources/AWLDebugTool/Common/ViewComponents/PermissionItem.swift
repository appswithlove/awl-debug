//
//  PermissionItem.swift
//  
//
//  Created by Hrvoje Hajduković on 19.09.2025..
//

import SwiftUI

struct PermissionItem: View {
    let status: RequestPermissionStatus
    let type: PermissionRequestType
    let available: Bool
    let openSystemPermissionRequest: () -> Void
    let openSettingsAction: () -> Void
    
    var body: some View {
        HStack {
            Label(type.title, systemImage: type.symbol)
            
            Spacer()
            
            Button {
                guard available else { return }
                
                switch status {
                case .notDetermined:
                    openSystemPermissionRequest()
                case .gotPermission, .denied:
                    openSettingsAction()
                }
            } label: {
                if !available {
                    Text(LS.Buttons.unavailable)
                        .foregroundStyle(.gray)
                } else {
                    switch status {
                    case .gotPermission, .denied:
                        Text(LS.Buttons.settings)
                    case .notDetermined:
                        Text(LS.Buttons.enable)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(!available ? .gray : (status == .gotPermission ? .gray : .blue))
            .disabled(!available)
        }
    }
}
