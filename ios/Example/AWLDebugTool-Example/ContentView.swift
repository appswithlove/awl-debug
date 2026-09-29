//
//  ContentView.swift
//  AWLDebugTool-Example
//
//  Created by Alain Stulz on 21.03.2024.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                FactView()
                
                Divider()
                
                VStack {
                    Text("Test screens:")
                    
                    NavigationLink("Screen recording") {
                        ScreenRecordingTestView()
                            .navigationTitle("Screen recording")
                    }
                    
                    NavigationLink("CPU") {
                        CpuTestView()
                            .navigationTitle("CPU")
                    }
                    
                    NavigationLink("Auth") {
                        AuthTestView()
                            .navigationTitle("Auth")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    ContentView()
}
