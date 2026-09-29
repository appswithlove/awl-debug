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
        case 400:
            self = .invalidRequest
        case 401, 403:
            self = .unauthorized
        case 413:
            self = .tooLarge
        case 415:
            self = .unsupportedMediaType
        case 429:
            self = .rateLimited(retryAfterSeconds: retryAfter.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) })
        case 500 ... 599:
            self = .serviceUnavailable
        default:
            self = .unexpectedStatus(statusCode)
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

    var message: String {
        switch self {
        case .invalidRequest:
            "The feedback service rejected the report as invalid."
        case .unauthorized:
            "This app is not registered with the feedback service (invalid or disabled app key)."
        case .tooLarge:
            "The report is too large to send."
        case .unsupportedMediaType:
            "The screenshot format was not accepted."
        case let .rateLimited(seconds?):
            "Too many reports. Try again in \(seconds) seconds."
        case .rateLimited(nil):
            "Too many reports. Try again later."
        case .serviceUnavailable:
            "The feedback service is unavailable. Try again later."
        case .offline:
            "No internet connection. Check your connection and try again."
        case .network:
            "The feedback service could not be reached. Try again."
        case let .unexpectedStatus(code):
            "Sending failed (HTTP \(code)). Try again."
        case .encodingFailed:
            "The screenshot could not be prepared."
        }
    }
}
