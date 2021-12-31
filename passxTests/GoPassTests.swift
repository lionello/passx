//
//  GoPassTests.swift
//  passxTests
//
//  Created by Lionello Lunesu on 2021-12-29.
//

import XCTest
@testable import passx

class GoPassTests: XCTestCase {
    let test = "zc.qq.com"
    let pass = GoPass(wrapper: "\(AppDelegate.HOME)/.config/gopass/gopass_wrapper.sh")

    func testGoPassLogin() throws {
        let pw = try pass.getLogin(entry: test)
        XCTAssertNotEqual(pw!, "")
    }

    func testGoPassQuery() throws {
        let pw = try pass.query(String(test.prefix(4)))
        XCTAssertEqual(pw, [test])
    }

    func testGoPassQueryHost() throws {
        let pw = try pass.queryHost(test)
        XCTAssertEqual(pw, [test])
    }
}
