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
                
                NavigationLink("Show new screen") {
                    AnotherView()
                        .navigationTitle("Test Screen")
                }
                
                cpuTestView()
            }
        }
    }
    
    private func cpuTestView() -> some View {
        VStack {
            Divider()
            
            Text("CPU test:")
            
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
        }
    }
}

struct AnotherView: View {
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

struct FactView: View {
    @State private var fact: String = ""
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "cat")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .font(.title)
                Text("Cat Fact")
                    .font(.title)
            }.padding(.bottom, 16)
            
            Text(fact)
            
            Spacer()
            
            Button("Load another fact") {
                Task {
                    try await loadFact()
                }
            }
        }
        .padding()
        .task {
            try? await loadFact()
        }
    }
    
    private func loadFact() async throws {
        let url = URL(string: "https://catfact.ninja/fact")!
        let request = URLRequest(url: url)
        let (data, _) = try await URLSession(configuration: .ephemeral).data(for: request)
        let decoder = JSONDecoder()
        let fact = try? decoder.decode(Fact.self, from: data)
        self.fact = fact?.fact ?? "No fact found"
    }
}

private struct Fact: Decodable {
    let fact: String
}

#Preview {
    ContentView()
}
