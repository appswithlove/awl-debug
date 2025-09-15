//
//  ScreenRecorderModel.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 15.09.2025.
//

import SwiftUI

public class ScreenRecorderModel: ObservableObject {
    var isDebugPanelVisible = false {
        didSet {
            if isDebugPanelVisible {
                stop()
            } else {
                startIfNeed()
            }
        }
    }
    
    @Published var isExportingVideo = false
    
    @Published var isScreenRecordingOn: Bool? = {
        if UserDefaults.standard.object(forKey: Constants.UserDefaults.screenRecordingIsOn) == nil {
            return nil
        }
        return UserDefaults.standard.bool(forKey: Constants.UserDefaults.screenRecordingIsOn)
    }() {
        didSet {
            UserDefaults.standard.set(isScreenRecordingOn, forKey: Constants.UserDefaults.screenRecordingIsOn)
        }
    }
    
    @Published var maxVideoDuration: Constants.MaxScreenVideoDuration = {
        return Constants.MaxScreenVideoDuration(rawValue: UserDefaults.standard.integer(forKey: Constants.UserDefaults.screenRecordingMaxVideoDuration)) ?? .fiveMinutes
    }() {
        didSet {
            UserDefaults.standard.set(maxVideoDuration.rawValue, forKey: Constants.UserDefaults.screenRecordingMaxVideoDuration)
        }
    }
    
    var isScreenRecordingOnByDefault: Bool = false
    
    func initialise(isScreenRecordingOn: Bool) {
        isScreenRecordingOnByDefault = isScreenRecordingOn
        startIfNeed()
    }
    
    func startIfNeed() {
        if (isScreenRecordingOn ?? isScreenRecordingOnByDefault) && !isDebugPanelVisible {
            ScreenRecorder.shared.start(duration: maxVideoDuration.rawValue)
        }
    }
    
    func stop() {
        ScreenRecorder.shared.stop()
    }
    
    func exportLastVideo() {
        self.isExportingVideo = true
        ScreenRecorder.shared.exportLastVideo {
            self.isExportingVideo = false
        }
    }
    
    func exportCurrentVideo() {
        self.isExportingVideo = true
        ScreenRecorder.shared.exportCurrentVideo {
            self.isExportingVideo = false
        }
    }
    
}

