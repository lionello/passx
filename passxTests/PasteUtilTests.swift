//
//  PasteUtilTests.swift
//  passxTests
//
//  Created by Lionello Lunesu on 2022-02-23.
//

import XCTest
@testable import passx

class PasteUtilTests: XCTestCase {

    func testTabReturn() throws {
        // FIXME: this test fails if an IME is active
        XCTAssertEqual([PasteUtil.KeyCode(vk: 48, flags: []), PasteUtil.KeyCode(vk: 36, flags: [])], try PasteUtil.stringToKeyCodes("\t\r"))
    }

}
