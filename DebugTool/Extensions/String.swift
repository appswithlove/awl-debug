//
//  String.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 15.06.2023..
//

import Foundation

extension String {
    var toLogTime: String {
        let date = Date.now
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df.string(from: date)
    }
}
