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
    
    func getLogin(entry: String, field: PassField) throws -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.gpg)
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        let path = NSString.path(withComponents: [self.store, entry]) + ".gpg"
        task.arguments = ["-d", path]
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw PassError.err(msg: try errorPipe.readUtf8())
        }

        let lines = try outputPipe.readUtf8()?.split(separator: "\n")
        // FIXME: .username should accept any of ["login", "username", "user"]
        if let pw = lines?.first(where: { $0.lowercased().starts(with: field.prefix())}) {
            // FIXME: calculate TOTP for .current_totp
            return String(pw)
        }
        return nil
    }
}

extension Pipe {
    
    func readUtf8() throws -> String? {
        guard let data = try self.fileHandleForReading.readToEnd() else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
