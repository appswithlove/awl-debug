//
//  FactView.swift
//  Sample
//
//

import OSLog
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
        var request = URLRequest(url: url)
        // Redacted in the Network module.
        request.setValue("Bearer example-token", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession(configuration: .ephemeral).data(for: request)
        let decoder = JSONDecoder()
        let fact = try? decoder.decode(Fact.self, from: data)
        self.fact = fact?.fact ?? "No fact found"
        // Shows up in the debug panel's Logs module without any SDK call.
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "Fact")
            .info("Loaded fact with \(data.count) bytes, Authorization: Bearer example-token")
    }
}

private struct Fact: Decodable {
    let fact: String
}

#Preview {
    FactView()
}
