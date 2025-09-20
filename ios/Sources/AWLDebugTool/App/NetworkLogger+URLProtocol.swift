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
    
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
        
        if session == nil {
            session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        }
    }
    
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
        sessionTask = session?.dataTask(with: newRequest as URLRequest)
        sessionTask?.resume()
        currentRequest = RequestInfo(request: newRequest)
    }
    
    override public func stopLoading() {
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
    
}

extension AWLDebugURLProtocol: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
//        if currentRequest?.dataResponse == nil {
//            currentRequest?.dataResponse = data
//        } else {
//            currentRequest?.dataResponse?.append(data)
//        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let policy = URLCache.StoragePolicy(rawValue: request.cachePolicy.rawValue) ?? .notAllowed
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: policy)
        currentRequest?.initResponse(response: response)
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            currentRequest?.errorDescription = error.localizedDescription
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        completionHandler(request)
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        guard let error = error else { return }
        currentRequest?.errorDescription = error.localizedDescription
        client?.urlProtocol(self, didFailWithError: error)
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let protectionSpace = challenge.protectionSpace
        let sender = challenge.sender
        
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                sender?.use(credential, for: challenge)
                completionHandler(.useCredential, credential)
                return
            }
        }
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            completionHandler(.performDefaultHandling, nil);
            return
        }
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        client?.urlProtocolDidFinishLoading(self)
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
