import Foundation
import Network

/// WebSocket echo server on 127.0.0.1: answers every message with the same message.
final class LocalWebSocketServer {

    private let listener: NWListener
    private let queue = DispatchQueue(label: "LocalWebSocketServer")
    private var connections: [NWConnection] = []

    init() throws {
        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(NWProtocolWebSocket.Options(), at: 0)
        listener = try NWListener(using: parameters, on: .any)
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

    /// `scheme` is `ws` or `http`; `URLSessionWebSocketTask` accepts both.
    func url(_ path: String, scheme: String = "ws") -> URL {
        URL(string: "\(scheme)://127.0.0.1:\(listener.port?.rawValue ?? 0)\(path)")!
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
        echo(on: connection)
    }

    private func echo(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard error == nil, let context else { return }
            let metadata = context.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
            guard metadata?.opcode != .close else {
                connection.cancel()
                return
            }
            let reply = NWConnection.ContentContext(identifier: "echo", metadata: [NWProtocolWebSocket.Metadata(opcode: metadata?.opcode ?? .text)])
            connection.send(content: data, contentContext: reply, isComplete: true, completion: .contentProcessed { _ in })
            self?.echo(on: connection)
        }
    }
}
