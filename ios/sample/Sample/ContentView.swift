//
//  ContentView.swift
//  Sample
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
                    
                    NavigationLink("Panel") {
                        PanelTestView()
                            .navigationTitle("Panel")
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
