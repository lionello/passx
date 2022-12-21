//
//  PassProtocol.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import Foundation

enum PassError : Error {
    case err(msg: String?)
    case notImplemented
    case invalidNativeMessage
}

enum PassField : String {
    case password
    case username
    case current_totp
    case url

    fileprivate func prefixes() -> [String] {
        switch self {
        case .password:
            return [""] // matches all lines
        case .username:
            return ["login:", "username:", "user:"] // TODO: require a space after :?
        case .current_totp:
            return ["totp:", "otpauth:"]
        case .url:
            return ["https:", "url:"]
        }
    }

    func isMatch(_ line: String) -> Bool {
        return prefixes().contains(where: line.hasPrefix)
    }
}

protocol PassProtocol {
    func getLogin(entry: String, field: PassField) async throws -> String?
    func query(_ query: String) async throws -> [String]
    func queryHost(_ host: String) async throws -> [String]
}
