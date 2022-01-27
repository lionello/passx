//
//  MockPass.swift
//  passx
//
//  Created by Lionello Lunesu on 2022-01-26.
//

import Foundation

class MockPass : PassProtocol {

    var passwords = ["mock/user":"pass"]

    func getLogin(entry: String, field: PassField) throws -> String? {
        if entry == "error" {
            throw PassError.err(msg: entry)
        }
        return field == .password ? passwords[entry] : nil
    }

    func query(_ query: String) throws -> [String] {
        if query == "error" {
            throw PassError.err(msg: query)
        }
        return passwords.keys.filter { $0.contains(query) }
    }

    func queryHost(_ host: String) throws -> [String] {
        if host == "error" {
            throw PassError.err(msg: host)
        }
        return passwords.keys.filter { $0.split(separator: "/").contains(host[host.startIndex...]) }
    }
}
