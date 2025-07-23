//
//  ContentView.swift
//  AWLDebugTool-Example
//
//  Created by Alain Stulz on 21.03.2024.
//

import SwiftUI
import AWLDebugTool

struct ContentView: View {
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
#if DEBUG || STAGING
        .includeDebugTool(customView: {
            DebugPanelView()
        })
#endif
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
                Text("Text \(model.testBool)")
                Toggle("Toggle", isOn: $model.testBool)
            } header: {
                Text("Custom section header 2")
            }
        }
    }
}
#endif

#Preview {
    ContentView()
}
