//
//  AWLDebugTool_ExampleApp.swift
//  AWLDebugTool-Example
//
//  Created by Alain Stulz on 21.03.2024.
//

import SwiftUI
import AWLDebugTool

@main
struct AWLDebugTool_ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    init() {
        AWLDebugTool.start(isScreenRecordingOn: true)
    }
}
