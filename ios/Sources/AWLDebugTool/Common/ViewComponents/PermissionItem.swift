//
//  PermissionItem.swift
//  
//
//  Created by Hrvoje Hajduković on 19.09.2025..
//

import SwiftUI

struct PermissionItem: View {
    let status: RequestPermissionStatus?
    let type: PermissionRequestType

    var body: some View {
        HStack {
            Label(type.title, systemImage: type.symbol)
            Spacer()
            Text((status ?? .unknown).title)
                .foregroundStyle(color)
        }
    }

    private var color: Color {
        switch status {
        case .granted, .provisional: return .green
        case .limited: return .orange
        case .denied: return .red
        case .notDetermined, .unknown, nil: return .secondary
        }
    }
}
