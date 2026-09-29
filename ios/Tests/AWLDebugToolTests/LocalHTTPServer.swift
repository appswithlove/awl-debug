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
    private var bodies: [String: Data] = [:]
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
    
    /// The decoded body of the last request to `path`.
    func receivedBody(_ path: String) -> Data? {
        queue.sync { bodies[path] }
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
        receive(on: connection, buffer: Data())
    }
    
    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            let buffer = buffer + (data ?? Data())
            if let (path, body) = Self.parseRequest(buffer) {
                self.respond(to: path, body: body, on: connection)
            } else if !isComplete && error == nil {
                self.receive(on: connection, buffer: buffer)
            }
        }
    }
    
    private func respond(to path: String, body: Data, on connection: NWConnection) {
        hits[path, default: 0] += 1
        bodies[path] = body
        
        let route = routes[path] ?? Response()
        guard let response = route else { return }
        var head = "HTTP/1.1 \(response.status)\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\n"
        for (name, value) in response.headers {
            head += "\(name): \(value)\r\n"
        }
        connection.send(content: Data((head + "\r\n").utf8) + response.body, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    /// `nil` until the head and the whole body (by `Content-Length` or chunked) arrived.
    private static func parseRequest(_ data: Data) -> (path: String, body: Data)? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headEnd = data.range(of: separator) else { return nil }
        let head = String(decoding: data[..<headEnd.lowerBound], as: UTF8.self)
        let lines = head.components(separatedBy: "\r\n")
        let target = lines[0].split(separator: " ").dropFirst().first.map(String.init) ?? "/"
        let path = target.components(separatedBy: "?")[0]
        func header(_ name: String) -> String? {
            lines.dropFirst()
                .first { $0.lowercased().hasPrefix(name + ":") }
                .map { $0.dropFirst(name.count + 1).trimmingCharacters(in: .whitespaces) }
        }
        let rest = data[headEnd.upperBound...]
        
        if header("transfer-encoding")?.lowercased() == "chunked" {
            guard let body = decodeChunked(rest) else { return nil }
            return (path, body)
        }
        let length = Int(header("content-length") ?? "") ?? 0
        guard rest.count >= length else { return nil }
        return (path, Data(rest.prefix(length)))
    }
    
    private static func decodeChunked(_ data: Data) -> Data? {
        let lineEnd = Data("\r\n".utf8)
        var body = Data()
        var index = data.startIndex
        while let sizeEnd = data.range(of: lineEnd, in: index..<data.endIndex) {
            let sizeText = String(decoding: data[index..<sizeEnd.lowerBound], as: UTF8.self).split(separator: ";").first ?? ""
            guard let size = Int(sizeText.trimmingCharacters(in: .whitespaces), radix: 16) else { return nil }
            if size == 0 {
                return body
            }
            let chunkEnd = sizeEnd.upperBound + size
            guard data.endIndex >= chunkEnd + lineEnd.count else { return nil }
            body.append(data[sizeEnd.upperBound..<chunkEnd])
            index = chunkEnd + lineEnd.count
        }
        return nil
    }
}
