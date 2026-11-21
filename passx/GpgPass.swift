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
    private let timeout: Duration

    init(gpg: String, store: String, timeout: Duration = defaultPassTimeout) {
        self.gpg = gpg
        self.store = store
        self.timeout = timeout
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
        // Kill gpg if it hangs (e.g. on a stuck scdaemon); that closes the pipes, so the reads below finish too
        let timeoutTask = process.terminate(after: timeout)
        // Drain both pipes before waiting, so the process can't block on a full pipe buffer
        async let output = outputPipe.fileHandleForReading.readUtf8()
        async let errors = errorPipe.fileHandleForReading.readUtf8()
        let (stdout, stderr) = try await (output, errors)
        process.waitUntilExit()
        timeoutTask.cancel()

        if await timeoutTask.value {
            throw PassError.timedOut(command: "gpg", after: timeout)
        }
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
