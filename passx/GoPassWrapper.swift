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
    private let timeout: Duration

    init(wrapper: String, timeout: Duration = defaultPassTimeout) {
        self.executable = wrapper
        self.arguments = []
        self.timeout = timeout
    }

    init(executable: String, arguments: [String] = [], timeout: Duration = defaultPassTimeout) {
        self.executable = executable
        self.arguments = arguments
        self.timeout = timeout
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
        // Kill gopass-jsonapi if it hangs (e.g. on a stuck scdaemon); that closes stdout, so the read below finishes too
        let timeoutTask = subprocess.process.terminate(after: timeout)
        defer {
            timeoutTask.cancel()
            subprocess.process.interrupt()
        }

        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        try subprocess.stdin.write(contentsOf: data.nativeMessage())

        let message: Data
        do {
            message = try await subprocess.stdout.nativeMessage()
        } catch {
            timeoutTask.cancel()
            if await timeoutTask.value {
                throw PassError.timedOut(command: (executable as NSString).lastPathComponent, after: timeout)
            }
            let stderrData = try? subprocess.stderr.readToEnd()
            let stderr = stderrData.flatMap { String(data: $0, encoding: .utf8) }
            if let stderr = stderr?.trimmingCharacters(in: .whitespacesAndNewlines), !stderr.isEmpty {
                throw PassError.err(msg: stderr)
            }
            throw error
        }
        let response: Any
        do {
            response = try JSONSerialization.jsonObject(with: message, options: [])
        } catch {
            throw PassError.err(msg: GoPassWrapper.invalidJsonMessage(request: json, data: message, error: error))
        }

        // Check for {"error":"…"} payload first
        if let map = response as? [String:Any] {
            if let error = map["error"] as? String {
                throw PassError.err(msg: error)
            }
        }
        return response
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

    private static func invalidJsonMessage(request: Any, data: Data, error: Error) -> String {
        let requestDescription: String
        if let requestData = try? JSONSerialization.data(withJSONObject: request, options: [.sortedKeys]),
           let requestString = String(data: requestData, encoding: .utf8) {
            requestDescription = requestString
        } else {
            requestDescription = String(describing: request)
        }
        let preview = String(data: data.prefix(512), encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            ?? data.prefix(128).map { String(format: "%02x", $0) }.joined(separator: " ")
        return "gopass-jsonapi returned invalid JSON for \(requestDescription) (\(data.count) bytes): \(error.localizedDescription). Payload: \(preview)"
    }
}

extension Data {

    init(nativeMessage: Data) {
        let size = UInt32(littleEndianBytes: nativeMessage.prefix(4))
        self.init(nativeMessage[4..<4+size])
    }

    func nativeMessage() -> Data {
        let prefix = UInt32(self.count).littleEndianBytes
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
        let len = UInt32(littleEndianBytes: [b0, b1, b2, b3])
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

extension UInt32 {
    fileprivate init(littleEndianBytes bytes: some Collection<UInt8>) {
        self = bytes.prefix(4).enumerated().reduce(UInt32(0)) { result, item in
            result | (UInt32(item.element) << UInt32(item.offset * 8))
        }
    }

    fileprivate var littleEndianBytes: Data {
        Data([
            UInt8(self & 0xff),
            UInt8((self >> 8) & 0xff),
            UInt8((self >> 16) & 0xff),
            UInt8((self >> 24) & 0xff),
        ])
    }
}
