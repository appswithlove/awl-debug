import Foundation
import SwiftUI

public class AWLDebugTool: ObservableObject {
    public static let shared = AWLDebugTool()
    let networkLogger = NetworkLogger()
    
    func simulateCrashExplicitly() {
        fatalError(Constants.Strings.fatalErrorMsg)
    }

    func simulateCrashImplicitly() {
        var testArray: [Int] = []
        _ = testArray.removeFirst()
        _ = 1 / testArray.count
    }
    
    public static func start() {
        shared.networkLogger.start()
    }
}
