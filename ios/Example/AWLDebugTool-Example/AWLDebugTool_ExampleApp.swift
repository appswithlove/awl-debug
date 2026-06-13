//
//  AWLDebugTool_ExampleApp.swift
//  AWLDebugTool-Example
//
//  Created by Alain Stulz on 21.03.2024.
//

import SwiftUI

#if DEBUG || STAGING
import AWLDebugTool
#endif

@main
struct AWLDebugTool_ExampleApp: App {
    
    init() {
#if DEBUG || STAGING
        AWLDebugTool.start(isScreenRecordingOn: true)
#endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
#if DEBUG || STAGING
                .includeDebugTool(customView: {
                    DebugPanelView()
                })
#endif
        }
    }
}

#if DEBUG || STAGING
class DebugPanelModel: ObservableObject {
    static let shared = DebugPanelModel()
    
    @Published var testBool: Bool = UserDefaults.standard.bool(forKey: "testBool") {
        didSet { UserDefaults.standard.set(testBool, forKey: "testBool") }
    }
}


struct DebugPanelView: View {
    @ObservedObject var model = DebugPanelModel.shared
    
    var body: some View {
        Group {
            Section {
                Button("Custom button 1") {
                    print("Custom button 1 Action")
                }
                Button("Custom button 2") {
                    print("Custom button 2 Action")
                }
            } header: {
                Text("Custom section header 1")
            }
            
            Section {
                Text("Text \(model.testBool.description)")
                Toggle("Toggle", isOn: $model.testBool)
            } header: {
                Text("Custom section header 2")
            }
        }
    }
}
#endif
