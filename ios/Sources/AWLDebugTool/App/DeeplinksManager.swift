//
//  DeeplinksManager.swift
//  AWLDebugTool
//

import Foundation
import UIKit
import UserNotifications

public class DeeplinksManager: ObservableObject {
    static let notificationURLKey = "AWLDebugToolDeeplinkURL"
    private static let notificationIdentifierPrefix = "AWLDebugTool.Deeplink."
    private static let userDefaultsKey = "AWLDebugTool.testerDeeplinks"

    private(set) var developerDeeplinks: [AWLDeeplink] = []
    private(set) var deeplinkHandler: ((URL) -> Void)?
    
    @Published var testerDeeplinks: [AWLDeeplink] = []

    func start(with model: AWLDebugTool.DeepLinkStartModel) {
        developerDeeplinks = model.deeplinks
        deeplinkHandler = {
            switch model.handler {
            case .uiApplicationSharedOpen: return nil
            case .custom(let handler): return handler
            }
        }()
    }
    
    init() {
        loadTesterDeeplinks()
    }

    // MARK: - Tester links

    func add(title: String, url: String) {
        testerDeeplinks.append(AWLDeeplink(title: title, url: url))
        save()
    }

    func remove(at offsets: IndexSet) {
        testerDeeplinks.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Firing

    func fireNow(_ deeplink: AWLDeeplink) {
        guard let url = URL(string: deeplink.url) else { return }
        fire(url)
    }

    /// A URL with a scheme, e.g. `myapp://path`; `nil` for anything else.
    static func validURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty else {
            return nil
        }
        return url
    }

    /// Closes the panel first, so the deeplink's target is visible.
    func fire(_ url: URL) {
        Task { @MainActor in
            AWLDebugTool.close()
            handleDeeplink(url)
        }
    }
    
    fileprivate func handleDeeplink(_ url: URL) {
        print("\(LS.logWatermark) Handling deeplink: \(url)")
        if let handler = deeplinkHandler {
            handler(url)
        } else {
            UIApplication.shared.open(url)
        }
    }

    /// Schedules the deeplink as a local notification. The tool never asks for the notification permission
    /// itself, so it does not change the app's own first-request flow; without it, this fails with `.permissionDenied`.
    func fireWithDelay(_ deeplink: AWLDeeplink, delay: TimeInterval, completion: @escaping (Result<Void, DeeplinkError>) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard Self.canSchedule(with: settings.authorizationStatus) else {
                DispatchQueue.main.async { completion(.failure(.permissionDenied)) }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = LS.Deeplinks.notificationTitle
            content.body = deeplink.title
            content.userInfo = [Self.notificationURLKey: deeplink.url]
            content.interruptionLevel = .timeSensitive

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let id = Self.notificationIdentifierPrefix + deeplink.id.uuidString
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                    if let _ = error {
                        completion(.failure(.schedulingFailed))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }

    static func canSchedule(with status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined, .denied: return false
        @unknown default: return false
        }
    }

    enum DeeplinkError: LocalizedError {
        case permissionDenied
        case schedulingFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return LS.Deeplinks.errorPermissionDenied
            case .schedulingFailed: return LS.Deeplinks.errorSchedulingFailed
            }
        }
    }

    // MARK: - Persistence

    private func loadTesterDeeplinks() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
              let deeplinks = try? JSONDecoder().decode([AWLDeeplink].self, from: data) else { return }
        testerDeeplinks = deeplinks
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(testerDeeplinks) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}

// MARK: - Start

extension AWLDebugTool {
    public struct DeepLinkStartModel {
        let deeplinks: [AWLDeeplink]
        let handler: DeeplinkHandler

        /// See also
        /// `AWLDebugTool.processDeeplinkNotificationIfNeeded()`. To handle local notifications.
        public init(deeplinks: [AWLDeeplink], handler: DeeplinkHandler) {
            self.deeplinks = deeplinks
            self.handler = handler
        }

        public enum DeeplinkHandler {
            /// URLs are opened using `UIApplication.shared.open(_:)`. This is sufficient when using custom URL schemes.
            case uiApplicationSharedOpen
            /// if your app does not use URL schemes, you have to call this your deep links  handler
            case custom(((URL) -> Void))
        }
    }
}

// MARK: - Public API

extension AWLDebugTool {
    /// Call this in your UNUserNotificationCenterDelegate to handle deeplink notifications fired by the debug tool.
    /// Returns true if the notification was handled.
    @discardableResult
    public static func processDeeplinkNotificationIfNeeded(_ response: UNNotificationResponse) -> Bool {
        return processDeeplinkNotificationInfoIfNeeded(response.notification.request.content.userInfo)
    }
    
    @discardableResult
    public static func processDeeplinkNotificationInfoIfNeeded(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let urlString = userInfo[DeeplinksManager.notificationURLKey] as? String,
              let url = URL(string: urlString) else { return false }
        shared.deeplinksManager.handleDeeplink(url)
        return true
    }
}
