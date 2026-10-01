//
//  NetworkLog.swift
//  AWLDebugTool
//
//  Copyright © 2023 Apps with love. All rights reserved.
//

import Foundation

struct NetworkLog: Codable, Identifiable {
    var id: UUID
    let method: String
    let url: String
    let date: Date
    let duration: Int
    let statusCode: Int
    var requestHeaders: [Header] = []
    var responseHeaders: [Header] = []
    var requestBody: Body?
    var responseBody: Body?
    var requestBytes: Int = 0
    var responseBytes: Int = 0
    var errorDescription: String?
    /// Short failure code for exports: `timeout`, `dns`, `tls`, `cancelled` or `connection`.
    var errorCode: String?
    var redactedCount: Int = 0
    
    struct Header: Codable, Hashable {
        let name: String
        let value: String
    }
    
    struct Body: Codable, Hashable {
        /// Redacted text, or a placeholder such as `(binary, 12 bytes)` when the content is not shown.
        let text: String
        let contentType: String?
        let originalBytes: Int
        var truncated = false
        /// `false` for placeholders; only text bodies can be replayed with cURL.
        var isText = true
    }
}

extension NetworkLog {
    /// Short failure code for exports and extensions: `timeout`, `dns`, `tls`, `cancelled` or `connection`.
    static func errorCode(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return "connection"
        }
        switch urlError.code {
        case .timedOut:
            return "timeout"
        case .cannotFindHost, .dnsLookupFailed:
            return "dns"
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected,
             .clientCertificateRequired, .appTransportSecurityRequiresSecureConnection:
            return "tls"
        case .cancelled:
            return "cancelled"
        default:
            return "connection"
        }
    }
}
