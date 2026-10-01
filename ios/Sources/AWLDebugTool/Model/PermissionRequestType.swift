//
//  PermissionRequestType.swift
//  AWLDebugTool
//

import Foundation

/// Permissions the module can show. Everything except notifications only appears when the app declares its
/// usage key, and its status is read only through a framework the app already loaded.
enum PermissionRequestType: String, Identifiable, CaseIterable {
    case locationAccess
    case cameraAccess
    case microphoneAccess
    case photosAccess
    case contactsAccess
    case calendarAccess
    case remindersAccess
    case bluetoothAccess
    case motionAccess
    case faceIDAccess
    case localNetworkAccess
    case trackingAccess
    case speechRecognitionAccess
    case notificationsAccess

    var id: String { rawValue }

    var title: String {
        switch self {
        case .locationAccess: return "Location"
        case .cameraAccess: return "Camera"
        case .microphoneAccess: return "Microphone"
        case .photosAccess: return "Photos"
        case .contactsAccess: return "Contacts"
        case .calendarAccess: return "Calendars"
        case .remindersAccess: return "Reminders"
        case .bluetoothAccess: return "Bluetooth"
        case .motionAccess: return "Motion"
        case .faceIDAccess: return "Face ID"
        case .localNetworkAccess: return "Local Network"
        case .trackingAccess: return "Tracking"
        case .speechRecognitionAccess: return "Speech Recognition"
        case .notificationsAccess: return "Notifications"
        }
    }

    var symbol: String {
        switch self {
        case .locationAccess: return "location.circle"
        case .cameraAccess: return "camera"
        case .microphoneAccess: return "mic"
        case .photosAccess: return "photo.on.rectangle"
        case .contactsAccess: return "person.crop.circle"
        case .calendarAccess: return "calendar"
        case .remindersAccess: return "list.bullet"
        case .bluetoothAccess: return "antenna.radiowaves.left.and.right"
        case .motionAccess: return "figure.walk"
        case .faceIDAccess: return "faceid"
        case .localNetworkAccess: return "network"
        case .trackingAccess: return "hand.raised"
        case .speechRecognitionAccess: return "waveform"
        case .notificationsAccess: return "bell"
        }
    }

    /// Any of these keys in the app's Info.plist declares the permission. Notifications need none.
    var usageKeys: [String] {
        switch self {
        case .locationAccess: return ["NSLocationWhenInUseUsageDescription", "NSLocationAlwaysAndWhenInUseUsageDescription"]
        case .cameraAccess: return ["NSCameraUsageDescription"]
        case .microphoneAccess: return ["NSMicrophoneUsageDescription"]
        case .photosAccess: return ["NSPhotoLibraryUsageDescription", "NSPhotoLibraryAddUsageDescription"]
        case .contactsAccess: return ["NSContactsUsageDescription"]
        case .calendarAccess: return ["NSCalendarsUsageDescription", "NSCalendarsFullAccessUsageDescription", "NSCalendarsWriteOnlyAccessUsageDescription"]
        case .remindersAccess: return ["NSRemindersUsageDescription", "NSRemindersFullAccessUsageDescription"]
        case .bluetoothAccess: return ["NSBluetoothAlwaysUsageDescription"]
        case .motionAccess: return ["NSMotionUsageDescription"]
        case .faceIDAccess: return ["NSFaceIDUsageDescription"]
        case .localNetworkAccess: return ["NSLocalNetworkUsageDescription"]
        case .trackingAccess: return ["NSUserTrackingUsageDescription"]
        case .speechRecognitionAccess: return ["NSSpeechRecognitionUsageDescription"]
        case .notificationsAccess: return []
        }
    }
}

enum RequestPermissionStatus: Equatable {
    case granted
    case denied
    case notDetermined
    case limited
    case provisional
    case unknown

    var title: String {
        switch self {
        case .granted: return LS.Permissions.granted
        case .denied: return LS.Permissions.denied
        case .notDetermined: return LS.Permissions.notDetermined
        case .limited: return LS.Permissions.limited
        case .provisional: return LS.Permissions.provisional
        case .unknown: return LS.Permissions.unknown
        }
    }
}
