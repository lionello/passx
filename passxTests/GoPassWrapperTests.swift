//
//  GoPassWrapperTests.swift
//  passxTests
//
//  Created by Lionello Lunesu on 2021-12-29.
//

import XCTest
@testable import passx

class GoPassWrapperTests: XCTestCase {
    let test = "zc.qq.com"
    let pass = GoPassWrapper(wrapper: "\(AppDelegate.HOME)/.config/gopass/gopass_wrapper.sh")

    func testGoPassLogin() async throws {
        let pw = try await pass.getLogin(entry: test, field: .password)
        XCTAssertNotEqual(pw!, "")
    }

    func testGoPassQuery() async throws {
        let pw = try await pass.query(String(test.prefix(4)))
        XCTAssertEqual(pw, [test])
    }

    func testGoPassQueryHost() async throws {
        let pw = try await pass.queryHost(test)
        XCTAssertEqual(pw, [test])
    }
}
