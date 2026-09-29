import Foundation

/// Reads a request body stream up to a limit so it can be captured, without losing any byte of the upload.
enum RequestBodyReader {

    enum Result {
        /// The stream ended within the limit; the request can carry `data` as `httpBody`.
        case complete(Data)
        /// The stream is longer than the limit; `upload.stream` replays the read bytes followed by the rest.
        case forwarded(ForwardedUpload)
        case failed(Error)
    }

    static let chunkSize = 64 * 1024

    /// Reads on a thread of its own, so neither the main thread nor the protocol thread blocks on a slow stream.
    /// - Parameter onFailure: Called when reading the rest of a forwarded stream fails, so the upload is not sent truncated.
    static func read(_ source: InputStream, limit: Int, onFailure: @escaping (Error) -> Void, completion: @escaping (Result) -> Void) {
        let thread = Thread {
            source.open()
            var prefix = Data()
            var buffer = [UInt8](repeating: 0, count: chunkSize)
            while prefix.count <= limit {
                let count = source.read(&buffer, maxLength: min(buffer.count, limit + 1 - prefix.count))
                if count < 0 {
                    source.close()
                    completion(.failed(source.streamError ?? URLError(.cannotDecodeRawData)))
                    return
                }
                if count == 0 {
                    source.close()
                    completion(.complete(prefix))
                    return
                }
                prefix.append(buffer, count: count)
            }
            let upload = ForwardedUpload(prefix: prefix)
            completion(.forwarded(upload))
            upload.pump(from: source, onFailure: onFailure)
        }
        thread.name = "AWLDebugTool.RequestBodyReader"
        thread.start()
    }

    final class ForwardedUpload {
        let prefix: Data
        let stream: InputStream
        private let output: OutputStream
        private let lock = NSLock()
        private var writtenBytes = 0

        /// Bytes handed to the upload so far; the whole body once the request finished.
        var totalBytes: Int {
            lock.lock()
            defer { lock.unlock() }
            return max(writtenBytes, prefix.count)
        }

        fileprivate init(prefix: Data) {
            self.prefix = prefix
            var input: InputStream?
            var output: OutputStream?
            Stream.getBoundStreams(withBufferSize: RequestBodyReader.chunkSize, inputStream: &input, outputStream: &output)
            stream = input!
            self.output = output!
        }

        /// Unblocks the pump when the request is stopped before `stream` was handed to a task.
        func cancel() {
            stream.open()
            stream.close()
        }

        /// Writes blocking: each write waits until the task read from `stream`, and fails once the task closed it.
        fileprivate func pump(from source: InputStream, onFailure: (Error) -> Void) {
            output.open()
            defer { source.close() }
            let prefixWritten = prefix.withUnsafeBytes { write($0.bindMemory(to: UInt8.self).baseAddress!, count: prefix.count) }
            guard prefixWritten else { return }

            var buffer = [UInt8](repeating: 0, count: RequestBodyReader.chunkSize)
            while true {
                let count = source.read(&buffer, maxLength: buffer.count)
                if count < 0 {
                    // Closing `output` would end the body early and send it truncated.
                    onFailure(source.streamError ?? URLError(.cannotDecodeRawData))
                    return
                }
                if count == 0 {
                    output.close()
                    return
                }
                guard write(buffer, count: count) else { return }
            }
        }

        private func write(_ bytes: UnsafePointer<UInt8>, count: Int) -> Bool {
            var offset = 0
            while offset < count {
                let written = output.write(bytes + offset, maxLength: count - offset)
                guard written > 0 else { return false }
                offset += written
                lock.lock()
                writtenBytes += written
                lock.unlock()
            }
            return true
        }
    }
}
