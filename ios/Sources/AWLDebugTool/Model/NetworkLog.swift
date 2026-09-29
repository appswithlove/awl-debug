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
    let date: Date
    let duration: Int
    let statusCode: Int
}
