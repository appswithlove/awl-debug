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

    var developerDeeplinks: [AWLDeeplink] = []
    var deeplinkHandler: ((URL) -> Void)?
    
    @Published var testerDeeplinks: [AWLDeeplink] = []

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
        handleDeeplink(url)
    }
    
    fileprivate func handleDeeplink(_ url: URL) {
        print("\(LS.logWatermark) Handling deeplink: \(url)")
        if let handler = deeplinkHandler {
            handler(url)
        } else {
            UIApplication.shared.open(url)
        }
    }

    func fireWithDelay(_ deeplink: AWLDeeplink, delay: TimeInterval, completion: @escaping (Result<Void, DeeplinkError>) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
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

// MARK: - Public API

extension AWLDebugTool {
    /// Call this in your UNUserNotificationCenterDelegate to handle deeplink notifications fired by the debug tool.
    /// Returns true if the notification was handled.
    @discardableResult
    public static func processDeeplinkNotificationIfNeeded(_ response: UNNotificationResponse) -> Bool {
        guard let urlString = response.notification.request.content.userInfo[DeeplinksManager.notificationURLKey] as? String,
              let url = URL(string: urlString) else { return false }
        shared.deeplinksManager.handleDeeplink(url)
        return true
    }
}
