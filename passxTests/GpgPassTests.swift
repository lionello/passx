//
//  GpgPassTests.swift
//  passxTests
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import XCTest
@testable import passx

class GpgPassTests: XCTestCase {
    let test = "zc.qq.com"
    let pass = GpgPass(gpg: "\(AppDelegate.HOME)/.nix-profile/bin/gpg", store: "\(AppDelegate.HOME)/.password-store")

    func testGpgPassLogin() throws {
        let pw = try pass.getLogin(entry: test)
        XCTAssertNotEqual(pw!, "")
    }

//    func testGoPassQuery() throws {
//        let pw = try pass.query(String(test.prefix(4)))
//        XCTAssertEqual(pw, [test])
//    }

//    func testGoPassQueryHost() throws {
//        let pw = try pass.queryHost(test)
//        XCTAssertEqual(pw, [test])
//    }
}
