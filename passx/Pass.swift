//
//  Pass.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import Foundation

enum PassError: Error {
    case err(msg: String?)
}

protocol Pass {
    func getLogin(entry: String) throws -> String?
}
