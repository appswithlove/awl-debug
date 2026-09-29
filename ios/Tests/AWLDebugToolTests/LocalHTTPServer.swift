import Foundation
import Network

/// Minimal HTTP/1.1 server on 127.0.0.1 for deterministic, real network tests.
final class LocalHTTPServer {
    
    struct Response {
        var status = "200 OK"
        var headers: [(String, String)] = []
        var body = Data("ok".utf8)
    }
    
    private let listener: NWListener
    private let queue = DispatchQueue(label: "LocalHTTPServer")
    private var routes: [String: Response?] = [:]
    private var hits: [String: Int] = [:]
    private var connections: [NWConnection] = []
    
    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
        _ = ready.wait(timeout: .now() + 5)
    }
    
    /// `nil` makes the server accept the request and never answer.
    func route(_ path: String, _ response: Response?) {
        queue.sync { routes[path] = .some(response) }
    }
    
    func url(_ path: String) -> URL {
        URL(string: "http://127.0.0.1:\(listener.port?.rawValue ?? 0)\(path)")!
    }
    
    func hitCount(_ path: String) -> Int {
        queue.sync { hits[path, default: 0] }
    }
    
    func stop() {
        queue.sync {
            listener.cancel()
            connections.forEach { $0.cancel() }
        }
    }
    
    private func handle(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, let requestText = String(data: data, encoding: .utf8) else { return }
            let target = requestText.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
            let path = target.components(separatedBy: "?")[0]
            self.hits[path, default: 0] += 1
            
            let route = self.routes[path] ?? Response()
            guard let response = route else { return }
            var head = "HTTP/1.1 \(response.status)\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\n"
            for (name, value) in response.headers {
                head += "\(name): \(value)\r\n"
            }
            connection.send(content: Data((head + "\r\n").utf8) + response.body, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
