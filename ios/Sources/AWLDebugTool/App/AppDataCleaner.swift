import Foundation
import Security

/// Deletes the app's own data from the device. The debug tool's settings and files are kept.
struct AppDataCleaner {
    enum Area: String, CaseIterable, Identifiable {
        case userDefaults
        case keychain
        case files
        case cookies

        var id: String { rawValue }

        var title: String {
            switch self {
            case .userDefaults: return LS.ClearData.userDefaults
            case .keychain: return LS.ClearData.keychain
            case .files: return LS.ClearData.files
            case .cookies: return LS.ClearData.cookies
            }
        }

        static let defaultSelection: Set<Area> = [.userDefaults]
    }

    /// Keys of the tool's own settings in `UserDefaults.standard`, including the reporter of AWLDebugFeedback.
    static let toolKeyPrefixes = ["AWLDebugTool", "AWLDebugFeedback", "DebugView."]
    /// The tool's own folders inside the app's directories.
    static let toolDirectoryNames: Set<String> = ["AWLDebug", "AWLDebugTool"]

    var defaults: UserDefaults = .standard
    var domainName: String? = Bundle.main.bundleIdentifier
    var appGroupIdentifiers: [String] = []
    var directories: [URL] = {
        let fileManager = FileManager.default
        return [fileManager.urls(for: .documentDirectory, in: .userDomainMask),
                fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask),
                fileManager.urls(for: .cachesDirectory, in: .userDomainMask)]
            .compactMap(\.first) + [fileManager.temporaryDirectory]
    }()

    func clear(_ areas: Set<Area>) {
        if areas.contains(.userDefaults) { clearUserDefaults() }
        if areas.contains(.keychain) { clearKeychain() }
        if areas.contains(.files) { clearFiles() }
        if areas.contains(.cookies) { clearCookiesAndCaches() }
    }

    func clearUserDefaults() {
        let keptPrefixes = Self.toolKeyPrefixes + ExtensionState.shared.keptUserDefaultsPrefixes
        let toolSettings = defaults.dictionaryRepresentation().filter { key, _ in
            keptPrefixes.contains { key.hasPrefix($0) }
        }
        if let domainName = domainName {
            defaults.removePersistentDomain(forName: domainName)
        }
        for (key, value) in toolSettings {
            defaults.set(value, forKey: key)
        }
        for group in appGroupIdentifiers {
            UserDefaults(suiteName: group)?.removePersistentDomain(forName: group)
        }
    }

    func clearKeychain() {
        let classes = [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassKey, kSecClassCertificate, kSecClassIdentity]
        for secClass in classes {
            SecItemDelete([kSecClass: secClass, kSecAttrSynchronizable: kSecAttrSynchronizableAny] as CFDictionary)
        }
    }

    func clearFiles() {
        let fileManager = FileManager.default
        for directory in directories {
            let contents = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for url in contents where !Self.toolDirectoryNames.contains(url.lastPathComponent) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    func clearCookiesAndCaches() {
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        URLCache.shared.removeAllCachedResponses()
    }
}
