//
//  NetworkLog.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 07.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import Foundation

struct NetworkLog: Codable, Identifiable {
    var id: UUID
    let method: String
    let url: String
}

extension NetworkLog {
    static func fixture() -> NetworkLog {
        return .init(id: UUID(), method: "GET", url: "https://getupdraft.com/1")
    }
    
    static func fixtures() -> [NetworkLog] {
        return [
            fixture(),
            .init(id: UUID(), method: "POST", url: "https://getupdraft.com/2"),
            .init(id: UUID(), method: "PATCH", url: "https://getupdraft.com/3"),
            .init(id: UUID(), method: "DELETE", url: "https://getupdraft.com/4")
        ]
    }
}
