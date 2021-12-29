//
//  Pipe.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import Foundation

extension Pipe {
    
    func readUtf8() throws -> String? {
        guard let data = try self.fileHandleForReading.readToEnd() else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    func readNativeMessage() throws -> Data? {
        guard let data = try self.fileHandleForReading.readToEnd() else {
            return nil
        }
        return Data(nativeMessage: data)
    }
}
