//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

/// Why a report could not be sent, with a message a tester can act on.
enum FeedbackError: Error, Equatable {
    case invalidRequest
    case unauthorized
    case tooLarge
    case unsupportedMediaType
    case rateLimited(retryAfterSeconds: Int?)
    case serviceUnavailable
    case offline
    case network
    case unexpectedStatus(Int)
    case encodingFailed

    init(statusCode: Int, retryAfter: String?) {
        switch statusCode {
        // 422: the service takes no reports from store builds; sending again cannot succeed.
        case 400, 422:
            self = .invalidRequest
        case 401, 403:
            self = .unauthorized
        case 413:
            self = .tooLarge
        case 415:
            self = .unsupportedMediaType
        case 429:
            self = .rateLimited(retryAfterSeconds: Self.seconds(retryAfter: retryAfter))
        case 500 ... 599:
            self = .serviceUnavailable
        default:
            self = .unexpectedStatus(statusCode)
        }
    }

    /// `Retry-After` in seconds; the HTTP-date form is not supported.
    static func seconds(retryAfter: String?) -> Int? {
        retryAfter.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }.map { max($0, 0) }
    }

    /// Network errors, timeouts, 5xx and 429 may pass; the report is kept and sent again later.
    var isRetryable: Bool {
        switch self {
        case .offline, .network, .serviceUnavailable, .rateLimited:
            true
        case .invalidRequest, .unauthorized, .tooLarge, .unsupportedMediaType, .unexpectedStatus, .encodingFailed:
            false
        }
    }

    init(urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            self = .offline
        default:
            self = .network
        }
    }

    /// The texts of the feedback spec, the same on Android.
    var message: String {
        switch self {
        case .invalidRequest:
            "The feedback service rejected the report."
        case .unauthorized:
            "This app is not registered with the feedback service (invalid or disabled app key)."
        case .tooLarge:
            "The report is too large to send."
        case .unsupportedMediaType:
            "The screenshot format was rejected by the feedback service."
        case let .rateLimited(seconds?):
            "Too many reports. Please try again in \(seconds) seconds."
        case .rateLimited(nil):
            "Too many reports. Please try again later."
        case .serviceUnavailable:
            "The feedback service is currently unavailable. Please try again."
        case .offline, .network:
            "No connection to the feedback service. Check your network and try again."
        case .unexpectedStatus:
            "Sending failed. Please try again."
        case .encodingFailed:
            "The screenshot could not be prepared."
        }
    }
}
