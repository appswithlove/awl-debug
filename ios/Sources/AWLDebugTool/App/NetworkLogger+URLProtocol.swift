import Foundation
import SwiftUI

extension URLSessionConfiguration {
    private static var didSwizzle = false
    
    static func setupSwizzle() {
        guard self == URLSessionConfiguration.self else {
            return
        }
        
        guard !didSwizzle else {
            return
        }
        didSwizzle = true
        
        let defaultSessionConfiguration = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.default))
        let swizzledDefaultSessionConfiguration = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.swizzledDefaultSessionConfiguration))
        method_exchangeImplementations(defaultSessionConfiguration!, swizzledDefaultSessionConfiguration!)
        
        let ephemeralSessionConfiguration = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.ephemeral))
        let swizzledEphemeralSessionConfiguration = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.swizzledEphemeralSessionConfiguration))
        method_exchangeImplementations(ephemeralSessionConfiguration!, swizzledEphemeralSessionConfiguration!)
    }
    
    @objc class func swizzledDefaultSessionConfiguration() -> URLSessionConfiguration {
        let configuration = swizzledDefaultSessionConfiguration()
        configuration.protocolClasses?.insert(AWLDebugURLProtocol.self, at: 0)
        URLProtocol.registerClass(AWLDebugURLProtocol.self)
        return configuration
    }
    
    @objc class func swizzledEphemeralSessionConfiguration() -> URLSessionConfiguration {
        let configuration = swizzledEphemeralSessionConfiguration()
        configuration.protocolClasses?.insert(AWLDebugURLProtocol.self, at: 0)
        URLProtocol.registerClass(AWLDebugURLProtocol.self)
        return configuration
    }
}

class AWLDebugURLProtocol: URLProtocol {
    
    struct Constants {
        static let RequestHandledKey = "AWLDebugURLProtocolRequestHandled"
    }
    
    var session: URLSession?
    var sessionTask: URLSessionDataTask?
    var currentRequest: RequestInfo?
    
    private let challengeLock = NSLock()
    private var pendingChallengeCompletion: ((URLSession.AuthChallengeDisposition, URLCredential?) -> Void)?
    
    private var clientRunLoop: CFRunLoop?
    private var clientRunLoopModes: [CFString] = []
    private var isStopped = false
    /// Client callbacks held back after a redirect until the app's session has decided about it.
    private var heldCallbacks: [(run: () -> Void, whenStopped: (() -> Void)?)]?
    /// Following a redirect stops this protocol well within this time; declining it does not signal anything.
    private static let redirectDecisionGrace: CFTimeInterval = 0.25
    
    override public class func canInit(with request: URLRequest) -> Bool {
        
        if AWLDebugURLProtocol.property(forKey: Constants.RequestHandledKey, in: request) != nil {
            return false
        }
        return true
    }
    
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override public func startLoading() {
        
        guard let newRequest = ((request as NSURLRequest).mutableCopy() as? NSMutableURLRequest) else {
            return
        }
        AWLDebugURLProtocol.setProperty(true, forKey: Constants.RequestHandledKey, in: newRequest)
        
        clientRunLoop = CFRunLoopGetCurrent()
        clientRunLoopModes = [CFRunLoopMode.defaultMode.rawValue]
        if let currentMode = RunLoop.current.currentMode, currentMode != .default {
            clientRunLoopModes.append(currentMode.rawValue as CFString)
        }
        
        let requestInfo = RequestInfo(request: newRequest, config: AWLDebugTool.shared.networkLogger.config)
        currentRequest = requestInfo
        // URLSession hands `httpBody` to URL protocols as `httpBodyStream`.
        guard let bodyStream = newRequest.httpBodyStream, let limit = requestInfo.requestBodyReadLimit else {
            startTask(with: newRequest)
            return
        }
        RequestBodyReader.read(bodyStream, limit: limit, onFailure: { [self] _ in
            performOnClientThread { [self] in
                sessionTask?.cancel()
            }
        }, completion: { [self] result in
            performOnClientThread({ [self] in
                switch result {
                case .complete(let data):
                    newRequest.httpBody = data
                    currentRequest?.setRequestBody(data)
                case .forwarded(let upload):
                    newRequest.httpBodyStream = upload.stream
                    currentRequest?.forwardedUpload = upload
                case .failed(let error):
                    currentRequest?.recordError(error)
                    client?.urlProtocol(self, didFailWithError: error)
                    return
                }
                startTask(with: newRequest)
            }, whenStopped: {
                if case .forwarded(let upload) = result {
                    upload.cancel()
                }
            })
        })
    }
    
    private func startTask(with request: NSMutableURLRequest) {
        session = URLSession(configuration: makeSessionConfiguration(), delegate: self, delegateQueue: nil)
        sessionTask = session?.dataTask(with: request as URLRequest)
        sessionTask?.resume()
    }
    
    override public func stopLoading() {
        isStopped = true
        releaseHeldCallbacks()
        resolvePendingChallenge(.cancelAuthenticationChallenge, nil)
        sessionTask?.cancel()
//        currentRequest?.httpBody = request.httpBodyStream?.readfully()
        if let startDate = currentRequest?.date {
            currentRequest?.duration = Int(Date().timeIntervalSince(startDate) * 1000)
        }
        
        // Redact here, so unredacted values never leave the running request.
        let log = currentRequest?.makeLog()
        currentRequest = nil
        
        DispatchQueue.main.async {
            if let log = log {
                AWLDebugTool.shared.networkLogger.appendNetworkLog(log)
            }
            
            self.session?.invalidateAndCancel()
        }
    }
    
    private func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = configuration.protocolClasses?.filter { ObjectIdentifier($0) != ObjectIdentifier(AWLDebugURLProtocol.self) }
        // The app's own session caches what this protocol forwards; a second cache here would answer requests without a network load or trust evaluation.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = request.timeoutInterval
        return configuration
    }
    
    /// URLProtocol clients must be called on the thread that called `startLoading`.
    private func performOnClientThread(_ block: @escaping () -> Void, whenStopped: (() -> Void)? = nil) {
        guard let clientRunLoop = clientRunLoop else {
            whenStopped?()
            return
        }
        CFRunLoopPerformBlock(clientRunLoop, clientRunLoopModes as CFArray) { [self] in
            if isStopped {
                whenStopped?()
            } else if heldCallbacks != nil {
                heldCallbacks?.append((block, whenStopped))
            } else {
                block()
            }
        }
        CFRunLoopWakeUp(clientRunLoop)
    }
    
    /// After `wasRedirectedTo`, the app's session asks its delegate asynchronously. Callbacks that arrive in the
    /// meantime could end the task before it follows the redirect, so they wait: if the session follows, it stops
    /// this protocol and they are dropped; if it declines, it expects the redirect response and they are delivered.
    private func holdCallbacksForRedirectDecision() {
        guard let clientRunLoop = clientRunLoop else { return }
        heldCallbacks = []
        let timer = CFRunLoopTimerCreateWithHandler(nil, CFAbsoluteTimeGetCurrent() + Self.redirectDecisionGrace, 0, 0, 0) { [self] _ in
            releaseHeldCallbacks()
        }
        for mode in clientRunLoopModes {
            CFRunLoopAddTimer(clientRunLoop, timer, CFRunLoopMode(mode))
        }
    }
    
    private func releaseHeldCallbacks() {
        let callbacks = heldCallbacks ?? []
        heldCallbacks = nil
        for callback in callbacks {
            if isStopped {
                callback.whenStopped?()
            } else {
                callback.run()
            }
        }
    }
}

extension AWLDebugURLProtocol: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        performOnClientThread { [self] in
            client?.urlProtocol(self, didLoad: data)
            currentRequest?.appendResponse(data)
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let policy = URLCache.StoragePolicy(rawValue: request.cachePolicy.rawValue) ?? .notAllowed
        performOnClientThread { [self] in
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: policy)
            currentRequest?.initResponse(response: response)
        }
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        performOnClientThread { [self] in
            if let error = error {
                currentRequest?.recordError(error)
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                client?.urlProtocolDidFinishLoading(self)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // The app's session decides about the redirect through its own delegate and loads it through this protocol again.
        // Not following it here keeps it a single request; if the app declines, the redirect response below becomes the final one.
        completionHandler(nil)
        guard let redirectRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        AWLDebugURLProtocol.removeProperty(forKey: Constants.RequestHandledKey, in: redirectRequest)
        performOnClientThread { [self] in
            currentRequest?.initResponse(response: response)
            client?.urlProtocol(self, wasRedirectedTo: redirectRequest as URLRequest, redirectResponse: response)
            holdCallbacksForRedirectDecision()
        }
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        guard let error = error else { return }
        performOnClientThread { [self] in
            currentRequest?.recordError(error)
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        performOnClientThread({ [self] in
            guard let client = client else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            
            // Forward the challenge to the app's own session delegate so its trust evaluation (e.g. pinning) and credentials apply.
            challengeLock.lock()
            pendingChallengeCompletion?(.cancelAuthenticationChallenge, nil)
            pendingChallengeCompletion = completionHandler
            challengeLock.unlock()
            
            let forwardedChallenge = URLAuthenticationChallenge(authenticationChallenge: challenge, sender: self)
            client.urlProtocol(self, didReceive: forwardedChallenge)
        }, whenStopped: {
            completionHandler(.cancelAuthenticationChallenge, nil)
        })
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        client?.urlProtocolDidFinishLoading(self)
    }
}

extension AWLDebugURLProtocol: URLAuthenticationChallengeSender {
    
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        resolvePendingChallenge(.useCredential, credential)
    }
    
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        resolvePendingChallenge(.useCredential, nil)
    }
    
    func cancel(_ challenge: URLAuthenticationChallenge) {
        resolvePendingChallenge(.cancelAuthenticationChallenge, nil)
    }
    
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {
        resolvePendingChallenge(.performDefaultHandling, nil)
    }
    
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {
        resolvePendingChallenge(.rejectProtectionSpace, nil)
    }
    
    private func resolvePendingChallenge(_ disposition: URLSession.AuthChallengeDisposition, _ credential: URLCredential?) {
        challengeLock.lock()
        let completion = pendingChallengeCompletion
        pendingChallengeCompletion = nil
        challengeLock.unlock()
        completion?(disposition, credential)
    }
}

//extension InputStream {
//    
//    func readfully() -> Data {
//        var result = Data()
//        var buffer = [UInt8](repeating: 0, count: 10 * 1024 * 1024)
//        
//        open()
//        
//        var amount = 0
//        repeat {
//            amount = read(&buffer, maxLength: buffer.count)
//            if amount > 0 {
//                result.append(buffer, count: amount)
//            }
//        } while amount > 0
//        
//        close()
//        
//        return result
//    }
//}

extension AWLDebugURLProtocol {
    /// Unredacted capture of the running request. Only the redacted result of `makeLog()` is stored.
    final class RequestInfo {
        
        let url: String
        let date: Date
        let method: String?
        let requestHeaders: [NetworkLog.Header]
        private(set) var requestBody: Data?
        private(set) var isRequestBodyStream: Bool
        /// Set when the body was longer than the read limit and is uploaded from a replaying stream.
        var forwardedUpload: RequestBodyReader.ForwardedUpload?
        var stausCode: Int
        var responseHeaders: [NetworkLog.Header] = []
        var errorDescription: String?
        var errorCode: String?
        var duration: Int?
        
        private let redactor: NetworkRedactor
        private var responseData = Data()
        private var responseBytes = 0
        private var isResponseStream = false
        private var responseCaptureLimit = 0
        
        init(request: NSURLRequest, config: AWLDebugConfig.NetworkConfig) {
            url = request.url?.absoluteString ?? ""
            date = Date()
            method = request.httpMethod
            requestHeaders = Self.sortedHeaders(request.allHTTPHeaderFields ?? [:])
            requestBody = request.httpBody
            isRequestBodyStream = request.httpBody == nil && request.httpBodyStream != nil
            stausCode = 0
            redactor = NetworkRedactor(config: config)
        }
        
        /// `nil` when the body stream is forwarded unread.
        var requestBodyReadLimit: Int? {
            let contentType = Self.value(of: "Content-Type", in: requestHeaders)
            guard isRequestBodyStream, redactor.config.captureBodies, !redactor.isStream(contentType: contentType) else {
                return nil
            }
            return redactor.captureLimit(contentType: contentType)
        }
        
        func recordError(_ error: Error) {
            errorDescription = error.localizedDescription
            errorCode = NetworkLog.errorCode(for: error)
        }
        
        func setRequestBody(_ data: Data) {
            requestBody = data
            isRequestBodyStream = false
        }
        
        func initResponse(response: URLResponse) {
            guard let responseHttp = response as? HTTPURLResponse else {return}
            stausCode = responseHttp.statusCode
            responseHeaders = Self.sortedHeaders(Dictionary(uniqueKeysWithValues: responseHttp.allHeaderFields.map { ("\($0.key)", "\($0.value)") }))
            
            let contentType = responseHttp.value(forHTTPHeaderField: "Content-Type")
            isResponseStream = redactor.isStreamResponse(statusCode: responseHttp.statusCode, contentType: contentType)
            if !redactor.config.captureBodies || isResponseStream {
                responseCaptureLimit = 0
            } else {
                responseCaptureLimit = redactor.captureLimit(contentType: contentType)
            }
        }
        
        func appendResponse(_ data: Data) {
            responseBytes += data.count
            let remaining = responseCaptureLimit - responseData.count
            if remaining > 0 {
                responseData.append(data.prefix(remaining))
            }
        }
        
        func makeLog() -> NetworkLog {
            var redactedCount = 0
            var log = NetworkLog(id: UUID(),
                                 method: method ?? "-",
                                 url: redactor.redact(url: url, count: &redactedCount),
                                 date: date,
                                 duration: duration ?? 0,
                                 statusCode: stausCode)
            log.requestHeaders = redactor.redact(headers: requestHeaders, count: &redactedCount)
            log.responseHeaders = redactor.redact(headers: responseHeaders, count: &redactedCount)
            log.requestBytes = forwardedUpload?.totalBytes ?? requestBody?.count ?? 0
            log.responseBytes = responseBytes
            log.errorDescription = errorDescription
            log.errorCode = errorCode
            
            if redactor.config.captureBodies {
                let requestContentType = Self.value(of: "Content-Type", in: requestHeaders)
                let responseContentType = Self.value(of: "Content-Type", in: responseHeaders)
                if let upload = forwardedUpload {
                    log.requestBody = redactor.redact(body: upload.prefix, totalBytes: upload.totalBytes, contentType: requestContentType, count: &redactedCount)
                } else if isRequestBodyStream {
                    log.requestBody = NetworkRedactor.placeholderBody(LS.Network.streamNotCaptured, contentType: requestContentType, totalBytes: 0)
                } else if let requestBody = requestBody {
                    log.requestBody = redactor.redact(body: requestBody, totalBytes: requestBody.count, contentType: requestContentType, count: &redactedCount)
                }
                if isResponseStream {
                    log.responseBody = NetworkRedactor.placeholderBody(LS.Network.streamNotCaptured, contentType: responseContentType, totalBytes: responseBytes)
                } else {
                    log.responseBody = redactor.redact(body: responseData, totalBytes: responseBytes, contentType: responseContentType, count: &redactedCount)
                }
            }
            log.redactedCount = redactedCount
            return log
        }
        
        private static func sortedHeaders(_ headers: [String: String]) -> [NetworkLog.Header] {
            headers.map { NetworkLog.Header(name: $0.key, value: $0.value) }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        
        private static func value(of name: String, in headers: [NetworkLog.Header]) -> String? {
            headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }
    }
}
