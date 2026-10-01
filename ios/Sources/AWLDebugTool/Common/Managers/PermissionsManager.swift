//
//  PermissionsManager.swift
//  AWLDebugTool
//

import ObjectiveC
import SwiftUI
import UserNotifications

/// Reads permission statuses without linking any permission framework: the SDK would otherwise need usage
/// keys the app may not have (ITMS-90683). A status is read only when the app itself loaded the framework.
@MainActor
class PermissionsManager: ObservableObject {
    @Published private(set) var statuses: [PermissionRequestType: RequestPermissionStatus] = [:]
    @Published private(set) var declaredTypes: [PermissionRequestType] = []

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        declaredTypes = PermissionRequestType.allCases.filter { type in
            type.usageKeys.isEmpty || bundle.hasPlistKeys(type.usageKeys)
        }
    }

    func refreshStatuses() async {
        var newStatuses: [PermissionRequestType: RequestPermissionStatus] = [:]
        for type in declaredTypes {
            newStatuses[type] = await status(for: type)
        }
        statuses = newStatuses
    }

    func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    private func status(for type: PermissionRequestType) async -> RequestPermissionStatus {
        switch type {
        case .notificationsAccess:
            switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
            case .authorized, .ephemeral: return .granted
            case .provisional: return .provisional
            case .denied: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .unknown
            }
        default:
            return Self.runtimeStatus(for: type)
        }
    }

    /// Raw values of the frameworks' authorization enums, read through the Objective-C runtime.
    static func runtimeStatus(for type: PermissionRequestType) -> RequestPermissionStatus {
        switch type {
        case .locationAccess:
            // CLAuthorizationStatus: notDetermined, restricted, denied, authorizedAlways, authorizedWhenInUse
            return map(ObjCStatus.int32(className: "CLLocationManager", selector: "authorizationStatus").map(Int.init),
                       [0: .notDetermined, 1: .denied, 2: .denied, 3: .granted, 4: .granted])
        case .cameraAccess, .microphoneAccess:
            // AVAuthorizationStatus: notDetermined, restricted, denied, authorized
            let mediaType = type == .cameraAccess ? "vide" : "soun"
            return map(ObjCStatus.int(className: "AVCaptureDevice", selector: "authorizationStatusForMediaType:", object: mediaType as NSString),
                       [0: .notDetermined, 1: .denied, 2: .denied, 3: .granted])
        case .photosAccess:
            // PHAuthorizationStatus for PHAccessLevelReadWrite: notDetermined, restricted, denied, authorized, limited
            return map(ObjCStatus.int(className: "PHPhotoLibrary", selector: "authorizationStatusForAccessLevel:", integer: 2),
                       [0: .notDetermined, 1: .denied, 2: .denied, 3: .granted, 4: .limited])
        case .contactsAccess:
            // CNAuthorizationStatus for CNEntityTypeContacts: notDetermined, restricted, denied, authorized, limited
            return map(ObjCStatus.int(className: "CNContactStore", selector: "authorizationStatusForEntityType:", integer: 0),
                       [0: .notDetermined, 1: .denied, 2: .denied, 3: .granted, 4: .limited])
        case .calendarAccess, .remindersAccess:
            // EKAuthorizationStatus: notDetermined, restricted, denied, fullAccess, writeOnly
            return map(ObjCStatus.int(className: "EKEventStore", selector: "authorizationStatusForEntityType:", integer: type == .calendarAccess ? 0 : 1),
                       [0: .notDetermined, 1: .denied, 2: .denied, 3: .granted, 4: .limited])
        case .bluetoothAccess:
            // CBManagerAuthorization: notDetermined, restricted, denied, allowedAlways
            return map(ObjCStatus.int(className: "CBManager", selector: "authorization"),
                       [0: .notDetermined, 1: .denied, 2: .denied, 3: .granted])
        case .motionAccess:
            // CMAuthorizationStatus: notDetermined, restricted, denied, authorized
            return map(ObjCStatus.int(className: "CMMotionActivityManager", selector: "authorizationStatus"),
                       [0: .notDetermined, 1: .denied, 2: .denied, 3: .granted])
        case .trackingAccess:
            // ATTrackingManagerAuthorizationStatus: notDetermined, restricted, denied, authorized
            return map(ObjCStatus.int(className: "ATTrackingManager", selector: "trackingAuthorizationStatus"),
                       [0: .notDetermined, 1: .denied, 2: .denied, 3: .granted])
        case .speechRecognitionAccess:
            // SFSpeechRecognizerAuthorizationStatus: notDetermined, denied, restricted, authorized
            return map(ObjCStatus.int(className: "SFSpeechRecognizer", selector: "authorizationStatus"),
                       [0: .notDetermined, 1: .denied, 2: .denied, 3: .granted])
        case .faceIDAccess, .localNetworkAccess, .notificationsAccess:
            // No status API without prompting.
            return .unknown
        }
    }

    private static func map(_ rawValue: Int?, _ statuses: [Int: RequestPermissionStatus]) -> RequestPermissionStatus {
        rawValue.flatMap { statuses[$0] } ?? .unknown
    }
}

/// Calls a class method of a class that is only looked up at runtime. `nil` when the class is not loaded.
enum ObjCStatus {
    private typealias IntGetter = @convention(c) (AnyClass, Selector) -> Int
    private typealias Int32Getter = @convention(c) (AnyClass, Selector) -> Int32
    private typealias IntForInt = @convention(c) (AnyClass, Selector, Int) -> Int
    private typealias IntForObject = @convention(c) (AnyClass, Selector, AnyObject) -> Int

    static func int(className: String, selector: String) -> Int? {
        implementation(className, selector).map { cls, sel, imp in unsafeBitCast(imp, to: IntGetter.self)(cls, sel) }
    }

    static func int32(className: String, selector: String) -> Int32? {
        implementation(className, selector).map { cls, sel, imp in unsafeBitCast(imp, to: Int32Getter.self)(cls, sel) }
    }

    static func int(className: String, selector: String, integer: Int) -> Int? {
        implementation(className, selector).map { cls, sel, imp in unsafeBitCast(imp, to: IntForInt.self)(cls, sel, integer) }
    }

    static func int(className: String, selector: String, object: AnyObject) -> Int? {
        implementation(className, selector).map { cls, sel, imp in unsafeBitCast(imp, to: IntForObject.self)(cls, sel, object) }
    }

    private static func implementation(_ className: String, _ selectorName: String) -> (AnyClass, Selector, IMP)? {
        let selector = NSSelectorFromString(selectorName)
        guard let cls = NSClassFromString(className), let method = class_getClassMethod(cls, selector) else {
            return nil
        }
        return (cls, selector, method_getImplementation(method))
    }
}
