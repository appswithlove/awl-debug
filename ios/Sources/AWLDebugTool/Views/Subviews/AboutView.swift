//
//  AboutView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI
import UIKit

/// App Info: the lines every bug report needs, one `Label: value` row each, in the order of the spec.
/// The device name is left out on purpose (generic since iOS 16, and personal before).
struct AboutView: View {
    let isOnline: Bool

    private static let timeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        return formatter
    }()

    var body: some View {
        Section {
            InfoRow(label: LS.AppInfo.app, value: Self.infoValue("CFBundleDisplayName") ?? Self.infoValue("CFBundleName"))
            InfoRow(label: LS.AppInfo.version, value: Self.infoValue("CFBundleShortVersionString"))
            InfoRow(label: LS.AppInfo.build, value: Self.infoValue("CFBundleVersion"))
            InfoRow(label: LS.AppInfo.device, value: ReportingSession.modelIdentifier)
            InfoRow(label: LS.AppInfo.os, value: "iOS \(UIDevice.current.systemVersion)")
            InfoRow(label: LS.AppInfo.locale, value: Locale.current.identifier(.bcp47))
            TimelineView(.periodic(from: .now, by: 1)) { context in
                InfoRow(label: LS.AppInfo.time, value: Self.timeFormatter.string(from: context.date))
            }
            InfoRow(label: LS.AppInfo.internet, value: isOnline ? LS.AppInfo.online : LS.AppInfo.offline)
        } header: {
            Text(LS.Headers.aboutSection)
        }
    }

    private static func infoValue(_ key: String) -> String? {
        (Bundle.main.infoDictionary?[key] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}

/// `Label: value`, side by side when it fits, stacked with large text. The value can be selected and copied.
struct InfoRow: View {
    let label: String
    let value: String

    init(label: String, value: String?) {
        self.label = label
        self.value = value ?? LS.Strings.unknownValue
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                Spacer(minLength: 16)
                valueText
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                valueText
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var valueText: some View {
        Text(value)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }
}

#Preview {
    Form {
        AboutView(isOnline: true)
    }
}
