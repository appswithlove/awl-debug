//
//  CpuTestView.swift
//  Example
//

import SwiftUI

struct CpuTestView: View {
    var body: some View {
        VStack {
            Text("CPU load test thread:")
            
            HStack {
                Button("Main") {
                    let finishDate = Date.now.addingTimeInterval(1)
                    while finishDate > Date.now {}
                }
                
                Button("Background") {
                    DispatchQueue.global(qos: .background).async {
                        let finishDate = Date.now.addingTimeInterval(10)
                        while finishDate > Date.now {}
                    }
                }
                
                Button("Utility") {
                    DispatchQueue.global(qos: .utility).async {
                        let finishDate = Date.now.addingTimeInterval(10)
                        while finishDate > Date.now {}
                    }
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    CpuTestView()
}
