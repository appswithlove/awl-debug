//
//  PermissionsManager.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 19.09.2025..
//

import AVFoundation
import Contacts
import EventKit
import MapKit
import Photos
import SwiftUI

@MainActor
class PermissionsManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var statuses: [PermissionRequestType: RequestPermissionStatus] = [:]
    @Published var availablePermissionRequestTypes: [PermissionRequestType] = []

    private var locationManager: CLLocationManager?
    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()

    override init() {
        super.init()
        Task { await refreshStatuses() }
        checkIfPermissionRequestTypesExistsInApp()
    }

    func refreshStatuses() async {
        var newStatuses: [PermissionRequestType: RequestPermissionStatus] = [:]

        for type in PermissionRequestType.allCases {
            newStatuses[type] = await checkStatus(for: type)
        }

        statuses = newStatuses
    }

    private func checkStatus(for type: PermissionRequestType) async -> RequestPermissionStatus {
        switch type {
        case .locationAccess:
            let status = CLLocationManager().authorizationStatus
            switch status {
            case .authorizedAlways, .authorizedWhenInUse: return .gotPermission
            case .denied, .restricted: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .denied
            }

        case .cameraAccess:
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return .gotPermission
            case .denied, .restricted: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .denied
            }

        case .microphoneAccess:
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: return .gotPermission
            case .denied, .restricted: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .denied
            }

        case .photosAccess:
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch status {
            case .authorized, .limited: return .gotPermission
            case .denied, .restricted: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .denied
            }

        case .contactsAccess:
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .authorized: return .gotPermission
            case .denied, .restricted: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .denied
            }

        case .calendarAccess:
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess: return .gotPermission
            case .denied, .restricted: return .denied
            case .notDetermined: return .notDetermined
            default: return .denied
            }

        case .remindersAccess:
            switch EKEventStore.authorizationStatus(for: .reminder) {
            case .fullAccess: return .gotPermission
            case .denied, .restricted: return .denied
            case .notDetermined: return .notDetermined
            default: return .denied
            }

        case .notificationsAccess:
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional: return .gotPermission
            case .denied: return .denied
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        }
    }
    
    func checkIfPermissionRequestTypesExistsInApp() {
        availablePermissionRequestTypes.removeAll()
        
        if let dict = Bundle.main.infoDictionary {
            print("📋 Full Info.plist keys at runtime:")
            for (key, value) in dict {
                print(" - \(key): \(value)")
            }
        }

        
        for permissionRequestType in PermissionRequestType.allCases {
            let requiredKeys = permissionRequestType.requiredPlistKeys
            
            // Notifications do not require keys, always add them
            if requiredKeys.isEmpty || Bundle.main.hasPlistKeys(requiredKeys) {
                availablePermissionRequestTypes.append(permissionRequestType)
                print("✅ Found permission: \(permissionRequestType)")
            } else {
                print("❌ Missing Info.plist keys for \(permissionRequestType)")
            }
        }
        
        print("📋 Available permissions in app:")
        print(availablePermissionRequestTypes)
    }
    
    func checkIfPermissionRequestTypeExistsInApp(_ type: PermissionRequestType) -> Bool {
        availablePermissionRequestTypes.contains(type)
    }

    
    func request(_ type: PermissionRequestType) async {
        if !Bundle.main.hasPlistKeys(type.requiredPlistKeys) {
            print("Missing Info.plist keys for \(type). Redirecting to Settings.")
            requestPermissionThroughSettings()
            return
        }

        switch type {
        case .locationAccess:
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.requestWhenInUseAuthorization()

        case .cameraAccess:
            _ = await AVCaptureDevice.requestAccess(for: .video)

        case .microphoneAccess:
            _ = await AVCaptureDevice.requestAccess(for: .audio)

        case .photosAccess:
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

        case .contactsAccess:
            _ = try? await contactStore.requestAccess(for: .contacts)

        case .calendarAccess:
            if #available(iOS 17, *) {
                _ = try? await eventStore.requestFullAccessToEvents()
            } else {
                _ = try? await eventStore.requestAccess(to: .event)
            }

        case .remindersAccess:
            if #available(iOS 17, *) {
                _ = try? await eventStore.requestFullAccessToReminders()
            } else {
                _ = try? await eventStore.requestAccess(to: .reminder)
            }

        case .notificationsAccess:
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        }

        await refreshStatuses()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { await refreshStatuses() }
    }
    
    func requestPermissionThroughSettings() {
        if let settings = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settings) {
            UIApplication.shared.open(settings)
        }
    }
    
    func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}
