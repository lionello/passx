//
//  MockPass.swift
//  passx
//
//  Created by Lionello Lunesu on 2022-01-26.
//

import Foundation

class MockPass : PassProtocol {

    var passwords = ["mock/user":"pass", "user":"pass2"]

    func getLogin(entry: String, field: PassField) throws -> String? {
        try enforceValid(entry)
        return field == .password ? passwords[entry] : nil
    }

    func query(_ query: String) throws -> [String] {
        try enforceValid(query)
        return passwords.keys.filter { $0.contains(query) }
    }

    func queryHost(_ host: String) throws -> [String] {
        try enforceValid(host)
        let hostSlice = host[host.startIndex...]
        return passwords.keys.filter { $0.split(separator: "/").contains(hostSlice) }
    }

    private func enforceValid(_ input: String) throws {
        if input == "error" {
            throw PassError.err(msg: input)
        }
    }
}
