//
//  ScreenRecordingTestView.swift
//  AWLDebugTool-Example
//
//  Created by Yanis Plumit on 30.06.2026.
//

import SwiftUI
#if DEBUG || STAGING
import AWLDebugTool
#endif

/// Store builds do not link AWLDebugTool, so the app wraps the marker in its own extension.
extension View {
    @ViewBuilder func debugMasked() -> some View {
#if DEBUG || STAGING
        awlDebugMasked()
#else
        self
#endif
    }
}

struct ScreenRecordingTestView: View {
    @State var showAlert = false
    @State var showSheet = false
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

            Text("Masked in recordings: IBAN CH00 0000 0000 0000 0000 0")
                .padding()
                .background(Color.orange)
                .debugMasked()

            Button("Show sheet") {
                showSheet = true
            }
            .padding()
            
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
        .sheet(isPresented: $showSheet) {
            VStack(spacing: 16) {
                Text("Sheet in the recording")
                SecureField("Sheet SecureField", text: $text)
                Button("Close") { showSheet = false }
            }
            .padding()
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
