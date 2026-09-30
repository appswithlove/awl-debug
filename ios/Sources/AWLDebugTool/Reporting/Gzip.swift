import Foundation
import zlib

enum Gzip {
    /// gzip-compressed `data` (RFC 1952), as sent with `Content-Encoding: gzip`.
    static func compress(_ data: Data) -> Data? {
        var stream = z_stream()
        // 15 window bits + 16 writes a gzip header and trailer instead of a zlib one.
        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY,
                            ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { deflateEnd(&stream) }

        var output = Data(count: Int(deflateBound(&stream, uLong(data.count))))
        let status: Int32 = data.withUnsafeBytes { input in
            output.withUnsafeMutableBytes { buffer in
                stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(input.count)
                stream.next_out = buffer.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(buffer.count)
                return deflate(&stream, Z_FINISH)
            }
        }
        guard status == Z_STREAM_END else { return nil }
        output.count = Int(stream.total_out)
        return output
    }
}
