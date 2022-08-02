//
//  GoPassWrapper.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//  Docs at https://github.com/gopasspw/gopass-jsonapi/blob/main/docs/api.md
//

import Foundation


class GoPassWrapper : PassProtocol {
    private let wrapper: String

    init(wrapper: String) {
        self.wrapper = wrapper
    }
    
    func getLogin(entry: String, field: PassField) async throws -> String? {
        let json: [String:String]  = [
            "type": field == .password || field == .username ? "getLogin" : "getData",
            "entry": entry,
        ]
        let map = try await invokeJsonApi(json) as! [String:Any]
        return map[field.rawValue] as? String
    }

    func query(_ query: String) async throws -> [String] {
        let json: [String:String]  = [
            "type": "query",
            "query": query,
        ]
        return try await invokeJsonApi(json) as! [String]
    }
    
    func queryHost(_ host: String) async throws -> [String] {
        let json: [String:String]  = [
            "type": "queryHost",
            "host": host,
        ]
        return try await invokeJsonApi(json) as! [String]
    }

    struct Subprocess {
        var process = Process()

        private var inputPipe = Pipe()
        private var outputPipe = Pipe()
        private var errorPipe = Pipe()

        init(wrapper: String) throws {
            process.executableURL = URL(fileURLWithPath: wrapper)
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe
//            process.arguments = TODO
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
        let subprocess = try Subprocess(wrapper: self.wrapper)
        defer {
            subprocess.process.interrupt()
        }

        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        try subprocess.stdin.write(contentsOf: data.nativeMessage())

        let message = try await subprocess.stdout.nativeMessage()
        let json = try JSONSerialization.jsonObject(with: message, options: [])

        // Check for {"error":"…"} payload first
        if let map = json as? [String:Any] {
            if let error = map["error"] as? String {
                throw PassError.err(msg: error)
            }
        }
        return json
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
        let prefix = Swift.withUnsafeBytes(of: Int32(self.count)) { Data($0) }
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
