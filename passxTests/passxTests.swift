//
//  passxTests.swift
//  passxTests
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import XCTest
@testable import passx

class passxTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGpgPass() throws {
        let pass = GpgPass(gpg: "/Users/llunesu/.nix-profile/bin/gpg", store: "/Users/llunesu/.password-store")
        let pw = try pass.getLogin(entry: "zc.qq.com")
        XCTAssertEqual(pw!, "")
    }

    func testGoPass() throws {
        let pass = GoPass(wrapper: "/Users/llunesu/.config/gopass/gopass_wrapper.sh")
        let pw = try pass.getLogin(entry: "zc.qq.com")
        XCTAssertEqual(pw!, "")
    }
}
