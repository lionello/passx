//
//  GoPass.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import Foundation


class GoPass : PassProtocol {
    private let wrapper: String
    
    init(wrapper: String) {
        self.wrapper = wrapper
    }
    
    func getLogin(entry: String) throws -> String? {
        let json: [String:String]  = [
             "type": "getLogin",
             "entry": entry,
        ]
        let map = try invokeJsonApi(json) as! [String:Any]
        return map["password"] as? String
    }
    
    func query(_ query: String) throws -> [String] {
        let json: [String:String]  = [
             "type": "query",
             "query": query,
        ]
        return try invokeJsonApi(json) as! [String]
    }
    
    func queryHost(_ host: String) throws -> [String] {
        let json: [String:String]  = [
             "type": "queryHost",
             "host": host,
        ]
        return try invokeJsonApi(json) as! [String]
    }
    
    private func invokeJsonApi(_ json: Any) throws -> Any {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.wrapper)
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        task.standardInput = inputPipe
        task.standardOutput = outputPipe
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        try inputPipe.fileHandleForWriting.write(contentsOf: data.nativeMessage())

        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw PassError.err(msg: try errorPipe.readUtf8())
        }
        return try JSONSerialization.jsonObject(with: try outputPipe.readNativeMessage()!, options: [])
    }
}

extension Data {

    init(nativeMessage: Data) {
        let size = nativeMessage.withUnsafeBytes {
            $0.load(as: Int32.self)
        }
        self.init(nativeMessage[4..<4+size])
    }

    func nativeMessage() -> Data {
        let prefix = Swift.withUnsafeBytes(of: Int32(self.count)) { Data($0) }
        return prefix + self
    }
}
