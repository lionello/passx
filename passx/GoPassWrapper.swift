//
//  GoPassWrapper.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//  Docs at https://github.com/gopasspw/gopass-jsonapi/blob/main/docs/api.md
//

import Foundation


class GoPassWrapper : PassProtocol {
    private let executable: String
    private let arguments: [String]

    init(wrapper: String) {
        self.executable = wrapper
        self.arguments = []
    }

    init(executable: String, arguments: [String] = []) {
        self.executable = executable
        self.arguments = arguments
    }
    
    func getLogin(entry: String, field: PassField) async throws -> String? {
        let json: [String:String]  = [
            "type": field == .password || field == .username ? "getLogin" : "getData",
            "entry": entry,
        ]
        guard let map = try await invokeJsonApi(json) as? [String:Any] else {
            throw PassError.err(msg: "Unexpected response format")
        }
        return map[field.rawValue] as? String
    }

    func query(_ query: String) async throws -> [String] {
        let json: [String:String]  = [
            "type": "query",
            "query": query,
        ]
        guard let result = try await invokeJsonApi(json) as? [String] else {
            throw PassError.err(msg: "Unexpected response format")
        }
        return result
    }

    func queryHost(_ host: String) async throws -> [String] {
        let json: [String:String]  = [
            "type": "queryHost",
            "host": host,
        ]
        guard let result = try await invokeJsonApi(json) as? [String] else {
            throw PassError.err(msg: "Unexpected response format")
        }
        return result
    }

    struct Subprocess {
        var process = Process()

        private var inputPipe = Pipe()
        private var outputPipe = Pipe()
        private var errorPipe = Pipe()

        init(executable: String, arguments: [String]) throws {
            if executable.contains("/") {
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [executable] + arguments
            }
            process.environment = GoPassWrapper.processEnvironment()
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            try process.run()
        }

        var stdout: FileHandle {
            return outputPipe.fileHandleForReading
        }

        var stdin: FileHandle {
            return inputPipe.fileHandleForWriting
        }

        var stderr: FileHandle {
            return errorPipe.fileHandleForReading
        }
    }

    private func invokeJsonApi(_ json: Any) async throws -> Any {
        let subprocess = try Subprocess(executable: self.executable, arguments: self.arguments)
        defer {
            subprocess.process.interrupt()
        }

        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        try subprocess.stdin.write(contentsOf: data.nativeMessage())

        let message: Data
        do {
            message = try await subprocess.stdout.nativeMessage()
        } catch {
            let stderrData = try? subprocess.stderr.readToEnd()
            let stderr = stderrData.flatMap { String(data: $0, encoding: .utf8) }
            if let stderr = stderr?.trimmingCharacters(in: .whitespacesAndNewlines), !stderr.isEmpty {
                throw PassError.err(msg: stderr)
            }
            throw error
        }
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: message, options: [])
        } catch {
            throw PassError.err(msg: "gopass-jsonapi returned a native message that was not valid JSON")
        }

        // Check for {"error":"…"} payload first
        if let map = json as? [String:Any] {
            if let error = map["error"] as? String {
                throw PassError.err(msg: error)
            }
        }
        return json
    }

    static func processEnvironment() -> [String:String] {
        var environment = ProcessInfo.processInfo.environment
        let defaultPath = [
            environment["PATH"],
            "/run/current-system/sw/bin",
            "\(AppDelegate.HOME)/.nix-profile/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/usr/local/MacGPG2/bin",
        ]
        environment["PATH"] = defaultPath.compactMap { $0 }.joined(separator: ":")
        return environment
    }
}

extension Data {

    init(nativeMessage: Data) {
        let size = UInt32(littleEndian: nativeMessage.withUnsafeBytes {
            $0.load(as: UInt32.self)
        })
        self.init(nativeMessage[4..<4+size])
    }

    func nativeMessage() -> Data {
        let prefix = Swift.withUnsafeBytes(of: Int32(self.count).littleEndian) { Data($0) }
        return prefix + self
    }
}

extension FileHandle {

    func nativeMessage() async throws -> Data {
        var base = bytes.makeAsyncIterator()
        guard let b0 = try await base.next(),
              let b1 = try await base.next(),
              let b2 = try await base.next(),
              let b3 = try await base.next() else {
            throw PassError.invalidNativeMessage
        }
        let len = UInt32(littleEndian: [b0, b1, b2, b3].withUnsafeBytes {
            $0.load(as: UInt32.self)
        })
        var data = Data()
        while let b = try await base.next() {
            data.append(b)
            if data.count == len { return data }
        }
        // Not a native message? Parse the data as an UTF8 error message
        var error = Data([b0, b1, b2, b3])
        error.append(data)
        throw PassError.err(msg: String(data: error, encoding: .utf8))
    }
}
