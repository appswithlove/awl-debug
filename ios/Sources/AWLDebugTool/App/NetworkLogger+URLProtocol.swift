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
        
        session = URLSession(configuration: makeSessionConfiguration(), delegate: self, delegateQueue: nil)
        sessionTask = session?.dataTask(with: newRequest as URLRequest)
        sessionTask?.resume()
        currentRequest = RequestInfo(request: newRequest)
    }
    
    override public func stopLoading() {
        isStopped = true
        resolvePendingChallenge(.cancelAuthenticationChallenge, nil)
        sessionTask?.cancel()
//        currentRequest?.httpBody = request.httpBodyStream?.readfully()
        if let startDate = currentRequest?.date {
            currentRequest?.duration = Int(Date().timeIntervalSince(startDate) * 1000)
        }
        
        DispatchQueue.main.async {
            if let currentRequest = self.currentRequest {
                AWLDebugTool.shared.networkLogger.appendNetworkLog(requestInfo: currentRequest)
                // print(currentRequest.url)
                // print(currentRequest.headers)
                // print(currentRequest.date)
                // print(currentRequest.stausCode)
                // print(currentRequest.duration)
                // print(currentRequest.responseHeaders)
                // print(currentRequest.errorDescription)
                // self.currentRequest?.dataResponse
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
            } else {
                block()
            }
        }
        CFRunLoopWakeUp(clientRunLoop)
    }
}

extension AWLDebugURLProtocol: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        performOnClientThread { [self] in
            client?.urlProtocol(self, didLoad: data)
        }
//        if currentRequest?.dataResponse == nil {
//            currentRequest?.dataResponse = data
//        } else {
//            currentRequest?.dataResponse?.append(data)
//        }
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
                currentRequest?.errorDescription = error.localizedDescription
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
            client?.urlProtocol(self, wasRedirectedTo: redirectRequest as URLRequest, redirectResponse: response)
        }
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        guard let error = error else { return }
        performOnClientThread { [self] in
            currentRequest?.errorDescription = error.localizedDescription
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
    class RequestInfo: Codable {
        
        let url: String
        let date: Date
        let method: String?
//        var headers: [String: String]?
//        var httpBody: Data?
        var stausCode: Int
//        var responseHeaders: [String: String]?
//        var dataResponse: Data?
        var errorDescription: String?
        var duration: Int?
        
        init(request: NSURLRequest) {
            url = request.url?.absoluteString ?? ""
            date = Date()
            method = request.httpMethod
//            headers = request.allHTTPHeaderFields
//            httpBody = request.httpBody
            stausCode = 0
        }
        
        func initResponse(response: URLResponse) {
            guard let responseHttp = response as? HTTPURLResponse else {return}
            stausCode = responseHttp.statusCode
//            responseHeaders = responseHttp.allHeaderFields as? [String: String]
        }
    }
}
