//
//  ScreenRecordingTestView.swift
//  AWLDebugTool-Example
//
//  Created by Yanis Plumit on 30.06.2026.
//

import SwiftUI

struct ScreenRecordingTestView: View {
    @State var showAlert = false
    @State var text: String = ""
    
    var body: some View {
        ScrollView {
            TextField("TextField", text: $text)
            SecureField("SecureField", text: $text)
            
            Button(action: {
                var a: [Int] = []
                a[0] = 1
            }, label: {
                Text("Crash")
                    .padding()
                    .background(Color.red)
                    .cornerRadius(5)
            })
            
            HStack {
                Color.white
                Color.black
            }.frame(height: 100)
            
            ForEach(0..<20, id: \.self) { i in
                Button(action: {
                    showAlert.toggle()
                }, label: {
                    Text("Show alert \(i)")
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(5)
                })
            }
            
            TextField("TextField", text: $text)
            SecureField("SecureField", text: $text)
        }
        .alert("Alert Example", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Message of the alert")
        }
    }
}

#Preview {
    ScreenRecordingTestView()
}
