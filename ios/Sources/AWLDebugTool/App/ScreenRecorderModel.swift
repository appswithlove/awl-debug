//
//  ScreenRecorderModel.swift
//  AWLDebugTool
//

import SwiftUI

public class ScreenRecorderModel: ObservableObject {
    /// Recording pauses while the panel is open.
    var isDebugPanelVisible = false {
        didSet {
            guard isDebugPanelVisible != oldValue else { return }
            Task { @MainActor in
                ScreenRecorder.shared.isPaused = isDebugPanelVisible
            }
        }
    }

    @Published var isExportingVideo = false
    /// Set when an export found no frames; shows "No recording yet".
    @Published var isRecordingEmpty = false
    /// When the newest frame of the previous run's recording was taken; `nil` without one.
    @Published private(set) var lastRecordingDate: Date?

    /// The tester's choice, stored per device; `nil` uses `isScreenRecordingOnByDefault`.
    @Published var isScreenRecordingOn: Bool? = {
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKey.screenRecordingIsOn) == nil {
            return nil
        }
        return UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.screenRecordingIsOn)
    }() {
        didSet {
            UserDefaults.standard.set(isScreenRecordingOn, forKey: Constants.UserDefaultsKey.screenRecordingIsOn)
            Task { @MainActor in startIfNeed() }
        }
    }

    /// The tester's choice, stored per device once changed in the panel; otherwise from the config.
    @Published var maxVideoDuration: Constants.MaxScreenVideoDuration = .fiveMinutes {
        didSet {
            guard !isApplyingConfig else { return }
            UserDefaults.standard.set(maxVideoDuration.rawValue, forKey: Constants.UserDefaultsKey.screenRecordingMaxVideoDuration)
            Task { @MainActor in
                ScreenRecorder.shared.stop()
                startIfNeed()
            }
        }
    }

    @Published var isScreenRecordingOnByDefault: Bool = false
    private var isApplyingConfig = false

    /// Whether recording is switched on; frames are still only taken while the app is used and the panel is closed.
    var isOn: Bool {
        isScreenRecordingOn ?? isScreenRecordingOnByDefault
    }

    @MainActor
    func initialise(config: AWLDebugConfig.ScreenRecordingConfig) {
        ScreenRecorder.shared.rotateOnce()
        lastRecordingDate = RecordingStorage.newestFrameDate(in: ScreenRecorder.shared.storage.lastFolder)
        isScreenRecordingOnByDefault = config.isOnByDefault
        let stored = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.screenRecordingMaxVideoDuration)
        isApplyingConfig = true
        maxVideoDuration = .closest(toSeconds: stored > 0 ? stored : Int(config.maxDuration.components.seconds))
        isApplyingConfig = false
        startIfNeed()
    }

    @MainActor
    func startIfNeed() {
        if isOn {
            ScreenRecorder.shared.start(maxDurationSeconds: maxVideoDuration.rawValue)
        } else {
            ScreenRecorder.shared.stop()
        }
    }

    @MainActor
    func exportLastVideo() {
        export(folder: ScreenRecorder.shared.storage.lastFolder)
    }

    @MainActor
    func exportCurrentVideo() {
        export(folder: ScreenRecorder.shared.storage.currentFolder)
    }

    @MainActor
    private func export(folder: URL) {
        isExportingVideo = true
        ScreenRecorder.shared.exportZip(folder: folder) { [weak self] hasFrames in
            self?.isExportingVideo = false
            self?.isRecordingEmpty = !hasFrames
        }
    }
}
