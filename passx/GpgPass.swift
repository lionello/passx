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
        if gpg.contains("/") {
            process.executableURL = URL(fileURLWithPath: self.gpg)
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [self.gpg]
        }
        process.environment = GoPassWrapper.processEnvironment()
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        let path = NSString.path(withComponents: [self.store, entry]) + ".gpg"
        process.arguments = (process.arguments ?? []) + ["-d", path]
        
        try process.run()
        // Drain both pipes before waiting, so the process can't block on a full pipe buffer
        async let output = outputPipe.fileHandleForReading.readUtf8()
        async let errors = errorPipe.fileHandleForReading.readUtf8()
        let (stdout, stderr) = try await (output, errors)
        process.waitUntilExit() // FIXME: blocks indefinitely if something's wrong with scdaemon

        if process.terminationStatus != 0 {
            throw PassError.err(msg: stderr)
        }

        let lines = stdout.split(separator: "\n")
        // FIXME: add special case for .url
        if let pw = lines.first(where: { field.isMatch($0.lowercased()) }) {
            // FIXME: calculate TOTP for .current_totp
            return String(pw)
        }
        return nil
    }
}

extension FileHandle {

    func readUtf8() async throws -> String {
        var data = Data()
        for try await byte in self.bytes {
            data.append(byte)
        }
        return String(decoding: data, as: UTF8.self)
    }
}
