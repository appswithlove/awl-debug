//
//  Constants.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 16.06.2023..
//

import Foundation

struct Constants {
    struct Defaults {
        static let defaultNumberOfLogs = [10, 50, 250, 500, defaultLogLimit, 1000]
        static let defaultLogLimit = 750
    }
    
    struct Strings {
        static let appName = "Debug Tool"
        static let unknownValue = "n/a"
        static let emptyString = ""
        static let fatalErrorMsg = "Don't worry be happy."
        static let searchLogs = "Search logs"
        static let tracking = "Track network logs"
        static let trackingInfo = "Add AWLDebugTool.start() into AppDelegate/App init() to enable this."
        static let stopTracking = "stop tracking network logs"
        static let startTracking = "start tracking network logs"
        static let logs = "Logs"
        static let numberOfLogs = "Number of requests: "
        static let emptyListOfLogs = "There is no logs"
        static let filters = "Filters"
    }
    
    struct Date {
        static let dateFormatSecondary = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    struct UserDefaults {
        private static let prefix = "AWLDebugTool_"
        static let networkLogsLimit = prefix + "networkLogsLimit"
        static let networkLogsSortingOrder = prefix + "networkLogsSortingOrder"
        static let networkLogsDynamicData = prefix + "networkLogsDynamicData"
        static let networkLogsEducationalMode = prefix + "networkLogsEducationalMode"
    }
    
    struct Headers {
        static let btnClose = "Close"
        static let btnDone = "Done"
        static let logs = "Logs"
        static let fcm = "FCM push token"
        static let aboutSection = "About"
        static let firebaseActions = "Firebase actions"
        static let settings = "Settings"
        static let requestMethods = "Request Methods"
        static let responseCodes = "Response Codes"
        static let endpoints = "Endpoints"
    }
    
    struct Alert {
        static let deleteNLTitle = "Deleting network logs"
        static let deleteNLMessage = "Are you sure you want to delete all network logs?"
        
        static let btnOK = "OK"
        static let btnCancel = "Cancel"
        static let btnDelete = "Delete"
    }
    
    struct Image {
        static let clear = "trash"
        static let export = "square.and.arrow.up"
        static let crash = "pip.remove"
        static let play = "play.fill"
        static let pause = "pause.fill"
        static let sortingOrder = "arrow.up.arrow.down"
        static let filtersUnset = "line.3.horizontal.decrease.circle"
        static let filtersSet = "line.3.horizontal.decrease.circle.fill"
        static let chevronUp = "chevron.up"
        static let chevronDown = "chevron.down"
    }
    
    struct Settings {
        static let logLimit = "Number of logs per session"
        static let exportFileName = "Export file name"
        static let sortingOrder = "Sort network logs"
        static let dynamicData = "Dynamic data"
        static let educationalMode = "Educational mode"
        static let darkMode = "Dark mode"
    }
    
    enum SortingOrder: String, CaseIterable, Identifiable {
        case ascending = "Ascending"
        case descending = "Descending"
        
        var id: String { self.rawValue }
    }
    
    struct Errors {
        static let savingDataToFile = "Unable to save network logs to file"
    }
    
    struct Actions {
        static let showNetworkLogs = "Show network logs"
        static let clearNetworkLogs = "Clear network logs"
        static let exportNetworkLogs = "Export network logs"
        
        static let simulateCrash = "Simulate crash"
        static let explicitCrash = "- explicit fatal error"
        static let implicitCrash = "- implicit fatal error"
    }
    
    struct Logs {
        static let initilize = "DT: init..."
        static let configureDT = "DT: configuring debug tool..."
        static let creatingDemoNL = "DT: creating demo network log..."
        static let creatingNL = "DT: creating network log..."
        static let loadingNL = "DT: loading network logs..."
        static let deletingNL = "DT: deleting network logs..."
        static let savingNL = "DT: saving network logs..."
        static let exportingNL = "DT: exporting logs..."
        static let savingSettings = "DT: saving settings..."
    }
    
    struct Values {
        static let enabledBtnOpacity: Double = 1
        static let disabledBtnOpacity: Double = 0.44
    }
    
    struct Buttons {
        static let deselectAllBtn: String = "DeselectAll"
        static let selectAllBtn: String = "SelectAll"
    }
    
    struct Regex {
        static let endpointsPattern = #"https?:\/\/[a-zA-Z0-9.-]+(?=\/)"#
    }
    
    // https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods
    enum RequestMethod: String, CaseIterable, Identifiable {
        case get = "GET"
        case head = "HEAD"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case connect = "CONNECT"
        case options = "OPTIONS"
        case trace = "TRACE"
        case patch = "PATCH"
        
        var id: String { self.rawValue }

        var description: String {
            switch self {
            case .get:
                "The GET method requests a representation of the specified resource. Requests using GET should only retrieve data."
            case .head:
                "The HEAD method asks for a response identical to a GET request, but without the response body."
            case .post:
                "The POST method submits an entity to the specified resource, often causing a change in state or side effects on the server."
            case .put:
                "The PUT method replaces all current representations of the target resource with the request payload."
            case .delete:
                "The DELETE method deletes the specified resource."
            case .connect:
                "The CONNECT method establishes a tunnel to the server identified by the target resource."
            case .options:
                "The OPTIONS method describes the communication options for the target resource."
            case .trace:
                "The TRACE method performs a message loop-back test along the path to the target resource."
            case .patch:
                "The PATCH method applies partial modifications to a resource."
            }
        }
        
        static subscript(method: String) -> String? {
            return RequestMethod(rawValue: method)?.description
        }
    }
    
    // https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
    enum ResponseCodes: Int, CaseIterable, Identifiable {
        case continueCode = 100
        case switchingProtocols = 101
        case processing  = 102
        case earlyHints = 103
        
        case ok = 200
        case created = 201
        case accepted = 202
        case nonAuthoritativeInformation = 203
        case noContent = 204
        case resetContent = 205
        case partialContent = 206
        case multiStatus = 207
        case alreadyReported = 208
        case imUsed = 226
        
        case multipleChoices = 300
        case movedPermanently = 301
        case found = 302
        case seeOther = 303
        case notModified = 304
        case useProxy = 305
        case unused = 306
        case temporaryRedirect = 307
        case permanentRedirect = 308
        
        case badRequest = 400
        case unauthorized = 401
        case paymentRequiredExperimental = 402
        case forbidden = 403
        case notFound = 404
        case methodNotAllowed = 405
        case notAcceptable = 406
        case proxyAuthenticationRequired = 407
        case requestTimeout = 408
        case conflict = 409
        case gone = 410
        case lengthRequired = 411
        case preconditionFailed = 412
        case payloadTooLarge = 413
        case URITooLong = 414
        case unsupportedMediaType = 415
        case rangeNotSatisfiable = 416
        case expectationFailed = 417
        case iAmATeapot = 418
        case misdirectedRequest = 421
        case unprocessableContent  = 422
        case locked = 423
        case failedDependency = 424
        case tooEarly = 425
        case upgradeRequired = 426
        case preconditionRequired = 428
        case tooManyRequests = 429
        case requestHeaderFieldsTooLarge = 431
        case unavailableForLegalReasons = 451
        
        
        case internalServerError = 500
        case notImplemented = 501
        case badGateway = 502
        case serviceUnavailable = 503
        case gatewayTimeout = 504
        case HTTPVersionNotSupported = 505
        case variantAlsoNegotiates = 506
        case insufficientStorage  = 507
        case loopDetected  = 508
        case notExtended = 510
        case networkAuthenticationRequired = 511
        
        var id: Int { self.rawValue }
        
        var description: String {
            switch self {
            case .continueCode:
                "This interim response indicates that the client should continue the request or ignore the response if the request is already finished."
            case .switchingProtocols:
                "This code is sent in response to an Upgrade request header from the client and indicates the protocol the server is switching to."
            case .processing:
                "This code indicates that the server has received and is processing the request, but no response is available yet."
            case .earlyHints:
                "This status code is primarily intended to be used with the Link header, letting the user agent start preloading resources while the server prepares a response or preconnect to an origin from which the page will need resources."
            case .ok:
                """
                The request succeeded. The result meaning of success depends on the HTTP method:
                GET: The resource has been fetched and transmitted in the message body.
                HEAD: The representation headers are included in the response without any message body.
                PUT or POST: The resource describing the result of the action is transmitted in the message body.
                TRACE: The message body contains the request message as received by the server.
                """
            case .created:
                "The request succeeded, and a new resource was created as a result. This is typically the response sent after POST requests, or some PUT requests."
            case .accepted:
                "The request has been received but not yet acted upon. It is noncommittal, since there is no way in HTTP to later send an asynchronous response indicating the outcome of the request. It is intended for cases where another process or server handles the request, or for batch processing."
            case .nonAuthoritativeInformation:
                "This response code means the returned metadata is not exactly the same as is available from the origin server, but is collected from a local or a third-party copy. This is mostly used for mirrors or backups of another resource. Except for that specific case, the 200 OK response is preferred to this status."
            case .noContent:
                "There is no content to send for this request, but the headers may be useful. The user agent may update its cached headers for this resource with the new ones."
            case .resetContent:
                "Tells the user agent to reset the document which sent this request."
            case .partialContent:
                "This response code is used when the Range header is sent from the client to request only part of a resource."
            case .multiStatus:
                "Conveys information about multiple resources, for situations where multiple status codes might be appropriate."
            case .alreadyReported:
                "Used inside a <dav:propstat> response element to avoid repeatedly enumerating the internal members of multiple bindings to the same collection."
            case .imUsed:
                "The server has fulfilled a GET request for the resource, and the response is a representation of the result of one or more instance-manipulations applied to the current instance."
            case .multipleChoices:
                "The request has more than one possible response. The user agent or user should choose one of them. (There is no standardized way of choosing one of the responses, but HTML links to the possibilities are recommended so the user can pick.)"
            case .movedPermanently:
                "The URL of the requested resource has been changed permanently. The new URL is given in the response."
            case .found:
                "This response code means that the URI of requested resource has been changed temporarily. Further changes in the URI might be made in the future. Therefore, this same URI should be used by the client in future requests."
            case .seeOther:
                "The server sent this response to direct the client to get the requested resource at another URI with a GET request."
            case .notModified:
                "This is used for caching purposes. It tells the client that the response has not been modified, so the client can continue to use the same cached version of the response."
            case .useProxy:
                "Defined in a previous version of the HTTP specification to indicate that a requested response must be accessed by a proxy. It has been deprecated due to security concerns regarding in-band configuration of a proxy."
            case .unused:
                "This response code is no longer used; it is just reserved. It was used in a previous version of the HTTP/1.1 specification."
            case .temporaryRedirect:
                "The server sends this response to direct the client to get the requested resource at another URI with the same method that was used in the prior request. This has the same semantics as the 302 Found HTTP response code, with the exception that the user agent must not change the HTTP method used: if a POST was used in the first request, a POST must be used in the second request."
            case .permanentRedirect:
                "This means that the resource is now permanently located at another URI, specified by the Location: HTTP Response header. This has the same semantics as the 301 Moved Permanently HTTP response code, with the exception that the user agent must not change the HTTP method used: if a POST was used in the first request, a POST must be used in the second request."
            case .badRequest:
                "The server cannot or will not process the request due to something that is perceived to be a client error (e.g., malformed request syntax, invalid request message framing, or deceptive request routing)."
            case .unauthorized:
                "Although the HTTP standard specifies unauthorized, semantically this response means unauthenticated. That is, the client must authenticate itself to get the requested response."
            case .paymentRequiredExperimental:
                "This response code is reserved for future use. The initial aim for creating this code was using it for digital payment systems, however this status code is used very rarely and no standard convention exists."
            case .forbidden:
                "The client does not have access rights to the content; that is, it is unauthorized, so the server is refusing to give the requested resource. Unlike 401 Unauthorized, the client's identity is known to the server."
            case .notFound:
                "The server cannot find the requested resource. In the browser, this means the URL is not recognized. In an API, this can also mean that the endpoint is valid but the resource itself does not exist. Servers may also send this response instead of 403 Forbidden to hide the existence of a resource from an unauthorized client. This response code is probably the most well known due to its frequent occurrence on the web."
            case .methodNotAllowed:
                "The request method is known by the server but is not supported by the target resource. For example, an API may not allow calling DELETE to remove a resource."
            case .notAcceptable:
                "This response is sent when the web server, after performing server-driven content negotiation, doesn't find any content that conforms to the criteria given by the user agent."
            case .proxyAuthenticationRequired:
                "This is similar to 401 Unauthorized but authentication is needed to be done by a proxy."
            case .requestTimeout:
                "This response is sent on an idle connection by some servers, even without any previous request by the client. It means that the server would like to shut down this unused connection. This response is used much more since some browsers, like Chrome, Firefox 27+, or IE9, use HTTP pre-connection mechanisms to speed up surfing. Also note that some servers merely shut down the connection without sending this message."
            case .conflict:
                "This response is sent when a request conflicts with the current state of the server."
            case .gone:
                "This response is sent when the requested content has been permanently deleted from server, with no forwarding address. Clients are expected to remove their caches and links to the resource. The HTTP specification intends this status code to be used for limited-time, promotional services. APIs should not feel compelled to indicate resources that have been deleted with this status code."
            case .lengthRequired:
                "Server rejected the request because the Content-Length header field is not defined and the server requires it."
            case .preconditionFailed:
                "The client has indicated preconditions in its headers which the server does not meet."
            case .payloadTooLarge:
                "Request entity is larger than limits defined by server. The server might close the connection or return an Retry-After header field."
            case .URITooLong:
                "The URI requested by the client is longer than the server is willing to interpret."
            case .unsupportedMediaType:
                "The media format of the requested data is not supported by the server, so the server is rejecting the request."
            case .rangeNotSatisfiable:
                "The range specified by the Range header field in the request cannot be fulfilled. It's possible that the range is outside the size of the target URI's data."
            case .expectationFailed:
                "This response code means the expectation indicated by the Expect request header field cannot be met by the server."
            case .iAmATeapot:
                "The server refuses the attempt to brew coffee with a teapot."
            case .misdirectedRequest:
                "The request was directed at a server that is not able to produce a response. This can be sent by a server that is not configured to produce responses for the combination of scheme and authority that are included in the request URI."
            case .unprocessableContent:
                "The request was well-formed but was unable to be followed due to semantic errors."
            case .locked:
                "The resource that is being accessed is locked."
            case .failedDependency:
                "The request failed due to failure of a previous request."
            case .tooEarly:
                "Indicates that the server is unwilling to risk processing a request that might be replayed."
            case .upgradeRequired:
                "The server refuses to perform the request using the current protocol but might be willing to do so after the client upgrades to a different protocol. The server sends an Upgrade header in a 426 response to indicate the required protocol(s)."
            case .preconditionRequired:
                "The origin server requires the request to be conditional. This response is intended to prevent the 'lost update' problem, where a client GETs a resource's state, modifies it and PUTs it back to the server, when meanwhile a third party has modified the state on the server, leading to a conflict."
            case .tooManyRequests:
                "The user has sent too many requests in a given amount of time (rate limiting)."
            case .requestHeaderFieldsTooLarge:
                "The server is unwilling to process the request because its header fields are too large. The request may be resubmitted after reducing the size of the request header fields."
            case .unavailableForLegalReasons:
                "The user agent requested a resource that cannot legally be provided, such as a web page censored by a government."
            case .internalServerError:
                "The server has encountered a situation it does not know how to handle."
            case .notImplemented:
                "The request method is not supported by the server and cannot be handled. The only methods that servers are required to support (and therefore that must not return this code) are GET and HEAD."
            case .badGateway:
                "This error response means that the server, while working as a gateway to get a response needed to handle the request, got an invalid response."
            case .serviceUnavailable:
                "The server is not ready to handle the request. Common causes are a server that is down for maintenance or that is overloaded. Note that together with this response, a user-friendly page explaining the problem should be sent. This response should be used for temporary conditions and the Retry-After HTTP header should, if possible, contain the estimated time before the recovery of the service. The webmaster must also take care about the caching-related headers that are sent along with this response, as these temporary condition responses should usually not be cached."
            case .gatewayTimeout:
                "This error response is given when the server is acting as a gateway and cannot get a response in time."
            case .HTTPVersionNotSupported:
                "The HTTP version used in the request is not supported by the server."
            case .variantAlsoNegotiates:
                "The server has an internal configuration error: the chosen variant resource is configured to engage in transparent content negotiation itself, and is therefore not a proper end point in the negotiation process."
            case .insufficientStorage:
                "The method could not be performed on the resource because the server is unable to store the representation needed to successfully complete the request."
            case .loopDetected:
                "The server detected an infinite loop while processing the request."
            case .notExtended:
                "Further extensions to the request are required for the server to fulfill it."
            case .networkAuthenticationRequired:
                "Indicates that the client needs to authenticate to gain network access."
            }
        }
        
        static subscript(code: Int) -> String? {
            return ResponseCodes(rawValue: code)?.description
        }
    }
}
