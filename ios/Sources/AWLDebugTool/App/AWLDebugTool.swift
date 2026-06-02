import Foundation
import SwiftUI

public class AWLDebugTool: ObservableObject {
    public static let shared = AWLDebugTool()
    let networkLogger = NetworkLogger()
    let screenRecorder = ScreenRecorderModel()
    
    func simulateCrashExplicitly() {
        fatalError(LS.Strings.fatalErrorMsg)
    }

    func simulateCrashImplicitly() {
        var testArray: [Int] = []
        _ = testArray.removeFirst()
        _ = 1 / testArray.count
    }
    
    /// Main init method.
    ///
    /// - Parameters:
    ///     - isScreenRecordingOn: default value. Can be changed on debug panel.
    ///
    public static func start(isScreenRecordingOn: Bool = false) {
        shared.networkLogger.start()
        shared.screenRecorder.initialise(isScreenRecordingOn: isScreenRecordingOn)
    }
}
