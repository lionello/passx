//
//  GpgPass.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import Foundation

class GpgPass : PassProtocol {
    
    func query(_ query: String) throws -> [String] {
        throw PassError.notImplemented
    }
    
    func queryHost(_ host: String) throws -> [String] {
        throw PassError.notImplemented
    }
    
    private let gpg: String
    private let store: String
    
    init(gpg: String, store: String) {
        self.gpg = gpg
        self.store = store
    }
    
    func getLogin(entry: String, field: PassField) async throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: self.gpg)
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        let path = NSString.path(withComponents: [self.store, entry]) + ".gpg"
        process.arguments = ["-d", path]
        
        try process.run()
        process.waitUntilExit() // FIXME: blocks indefinitely if something's wrong with scdaemon
        
        if process.terminationStatus != 0 {
            throw PassError.err(msg: try errorPipe.fileHandleForReading.readUtf8())
        }

        let lines = try outputPipe.fileHandleForReading.readUtf8()?.split(separator: "\n")
        // FIXME: add special case for .url
        if let pw = lines?.first(where: { field.isMatch($0.lowercased()) }) {
            // FIXME: calculate TOTP for .current_totp
            return String(pw)
        }
        return nil
    }
}

extension FileHandle {

    @available(*, deprecated, message: "blocking")
    func readUtf8() throws -> String? {
        guard let data = try self.readToEnd() else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
