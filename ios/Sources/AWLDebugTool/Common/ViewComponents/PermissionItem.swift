//
//  PermissionItem.swift
//  
//

import SwiftUI

struct PermissionItem: View {
    let status: RequestPermissionStatus?
    let type: PermissionRequestType

    var body: some View {
        // Name and status side by side; stacked with large text.
        ViewThatFits(in: .horizontal) {
            HStack {
                title
                Spacer()
                statusText
            }
            VStack(alignment: .leading, spacing: 4) {
                title
                statusText
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Label(type.title, systemImage: type.symbol)
    }

    private var statusText: some View {
        Text((status ?? .unknown).title)
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .granted, .provisional: return .statusPositive
        case .limited: return .statusWarning
        case .denied: return .statusError
        case .notDetermined, .unknown, nil: return .secondary
        }
    }
}
