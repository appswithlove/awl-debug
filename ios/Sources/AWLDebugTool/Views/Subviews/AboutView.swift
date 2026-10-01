import SwiftUI
import UIKit

/// App Info: the lines every bug report needs, one `Label: value` row each, in the same order as on Android.
/// The header collapses it to one summary line; the choice is stored on the device and kept by Clear App Data.
/// The device name is left out on purpose (generic since iOS 16, and personal before).
struct AboutView: View {
    let isOnline: Bool
    @AppStorage(Constants.UserDefaultsKey.appInfoExpanded) private var isExpanded = true

    private static let timeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        return formatter
    }()

    var body: some View {
        Section {
            if isExpanded {
                InfoRow(label: LS.AppInfo.app, value: Self.appName)
                InfoRow(label: LS.AppInfo.version, value: Self.infoValue("CFBundleShortVersionString"))
                InfoRow(label: LS.AppInfo.build, value: Self.infoValue("CFBundleVersion"))
                InfoRow(label: LS.AppInfo.device, value: Self.modelIdentifier)
                InfoRow(label: LS.AppInfo.os, value: Self.osVersion)
                InfoRow(label: LS.AppInfo.locale, value: Locale.current.identifier(.bcp47))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    InfoRow(label: LS.AppInfo.time, value: Self.timeFormatter.string(from: context.date))
                }
                InfoRow(label: LS.AppInfo.internet, value: isOnline ? LS.AppInfo.online : LS.AppInfo.offline)
            } else {
                Text(Self.summary(isOnline: isOnline))
                    .textSelection(.enabled)
            }
        } header: {
            header
        }
    }

    /// The whole header toggles the section; VoiceOver reads it as one button with its state.
    private var header: some View {
        Button {
            withAnimation { isExpanded.toggle() }
        } label: {
            HStack {
                Text(LS.Headers.aboutSection)
                Spacer()
                Image.with(icon: isExpanded ? .chevronUp : .chevronDown)
                    .foregroundStyle(.tint)
                    .padding(6)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(isExpanded ? LS.Buttons.expanded : LS.Buttons.collapsed)
    }

    /// Collapsed App Info: "MyApp 1.0 (42) · iOS 18.0 · Online".
    @MainActor static func summary(isOnline: Bool) -> String {
        let version = infoValue("CFBundleShortVersionString").map { version in
            infoValue("CFBundleVersion").map { "\(version) (\($0))" } ?? version
        }
        let app = [appName, version].compactMap { $0 }.joined(separator: " ")
        return [app, osVersion, isOnline ? LS.AppInfo.online : LS.AppInfo.offline]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private static var appName: String? {
        infoValue("CFBundleDisplayName") ?? infoValue("CFBundleName")
    }

    @MainActor private static var osVersion: String {
        "iOS \(UIDevice.current.systemVersion)"
    }

    /// Hardware identifier such as `iPhone17,1`; on the simulator the simulated device's.
    static var modelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(bytes: buffer.prefix { $0 != 0 }, encoding: .utf8) ?? ""
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
