//
//  Pass.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import Foundation

enum PassError: Error {
    case err(msg: String?)
    case notImplemented
    case invalidNativeMessage
}

enum PassField : String {
    case password
    case username
    case current_totp
    case url

    func prefix() -> String {
        if self == .password {
            return ""
        }
        return self.rawValue + ": "
    }
}

protocol PassProtocol {
    func getLogin(entry: String, field: PassField) async throws -> String?
    func query(_ query: String) async throws -> [String]
    func queryHost(_ host: String) async throws -> [String]
}
