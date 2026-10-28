//
//  AWLDeeplink.swift
//  AWLDebugTool
//

import Foundation

public struct AWLDeeplink: Codable, Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let url: String

    public init(title: String, url: String) {
        self.id = UUID()
        self.title = title
        self.url = url
    }
}
