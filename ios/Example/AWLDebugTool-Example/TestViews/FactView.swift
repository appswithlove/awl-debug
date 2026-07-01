//
//  FactView.swift
//  AWLDebugTool-Example
//
//  Created by Yanis Plumit on 30.06.2026.
//

import SwiftUI

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
    FactView()
}
