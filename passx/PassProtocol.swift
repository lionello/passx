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
}

enum PassField : String {
    case password
    case username
    case otpauth
    case url

    func prefix() -> String {
        if self == .password {
            return ""
        }
        return self.rawValue + ": "
    }
}

protocol PassProtocol {
    func getLogin(entry: String, field: PassField) throws -> String?
    func query(_ query: String) throws -> [String]
    func queryHost(_ host: String) throws -> [String]
}
