//
//  TextDocument.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 19.06.2023..
//

import SwiftUI
import UniformTypeIdentifiers

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.plainText]
    }
    
    var text = Constants.Strings.emptyString
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = Constants.Strings.emptyString
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
