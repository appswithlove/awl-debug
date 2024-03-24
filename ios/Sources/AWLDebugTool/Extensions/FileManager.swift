//
//  FileManager.swift
//  AWLDebugTool
//
//  Created by Hrvoje Hajduković on 12.06.2023..
//  Copyright © 2023 Apps with love. All rights reserved.
//

import Foundation

extension FileManager {
    static var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
