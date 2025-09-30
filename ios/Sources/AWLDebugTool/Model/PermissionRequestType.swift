//
//  PermissionRequestType.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 19.09.2025..
//

import Foundation
import SwiftUI
import AVFoundation
import Photos
// TODO: fixme - ITMS-90683: Missing purpose string in Info.plist
//import Contacts
//import EventKit
import UserNotifications
import CoreLocation

enum PermissionRequestType: String, Identifiable, CaseIterable {
    // TODO: fixme - ITMS-90683: Missing purpose string in Info.plist
//    case locationAccess
//    case cameraAccess
//    case microphoneAccess
//    case photosAccess
//    case contactsAccess
//    case calendarAccess
//    case remindersAccess
    case notificationsAccess

    var id: String { rawValue }

    var title: String {
        switch self {
        // TODO: fixme - ITMS-90683: Missing purpose string in Info.plist
//        case .locationAccess: return "Location"
//        case .cameraAccess: return "Camera"
//        case .microphoneAccess: return "Microphone"
//        case .photosAccess: return "Photos"
//        case .contactsAccess: return "Contacts"
//        case .calendarAccess: return "Calendar"
//        case .remindersAccess: return "Reminders"
        case .notificationsAccess: return "Notifications"
        }
    }

    var symbol: String {
        switch self {
        // TODO: fixme - ITMS-90683: Missing purpose string in Info.plist
//        case .locationAccess: return "location.circle"
//        case .cameraAccess: return "camera"
//        case .microphoneAccess: return "mic"
//        case .photosAccess: return "photo.on.rectangle"
//        case .contactsAccess: return "person.crop.circle"
//        case .calendarAccess: return "calendar"
//        case .remindersAccess: return "list.bullet"
        case .notificationsAccess: return "bell"
        }
    }
    
    var isInfoPlistKeyNecessary: Bool {
        switch self {
        case .notificationsAccess: return false
        default: return true
        }
    }
}

extension PermissionRequestType {
    var requiredPlistKeys: [String] {
        switch self {
        // TODO: fixme - ITMS-90683: Missing purpose string in Info.plist
//        case .cameraAccess:
//            return ["NSCameraUsageDescription"]
//        case .microphoneAccess:
//            return ["NSMicrophoneUsageDescription"]
//        case .photosAccess:
//            return ["NSPhotoLibraryUsageDescription"]
//        case .locationAccess:
//            return [
//                "NSLocationWhenInUseUsageDescription",
//                "NSLocationAlwaysAndWhenInUseUsageDescription"
//            ]
//        case .contactsAccess:
//            return ["NSContactsUsageDescription"]
//        case .calendarAccess:
//            return ["NSCalendarsUsageDescription"]
//        case .remindersAccess:
//            return ["NSRemindersUsageDescription"]
        case .notificationsAccess:
            // Notifications do NOT require Info.plist keys
            return []
        }
    }
}

enum RequestPermissionStatus {
    case notDetermined
    case denied
    case gotPermission
}
