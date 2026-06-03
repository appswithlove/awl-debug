//
//  Constants+Response.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 02.06.2026.
//

extension Constants {
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
        
        static subscript(method: String) -> String? {
            return RequestMethod(rawValue: method)?.description
        }
    }
}

extension Constants.RequestMethod {
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
}
