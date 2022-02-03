//
//  PassViewModelTests.swift
//  passxTests
//
//  Created by Lionello Lunesu on 2022-01-29.
//

import XCTest
@testable import passx

class PassViewModelTests : XCTestCase {

    private let mockPass = MockPass()

    func testHappy() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("m")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst().first())
        XCTAssertEqual(entries, ["mock/user"])
        XCTAssertEqual(vm.suggestion, "mock/user")
    }

    func testEntriesMatchesSubstring() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("ock")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst().first())
        XCTAssertEqual(entries, ["mock/user"])
        XCTAssertNil(vm.suggestion)
    }

    func testSuggestionMatchesPrefix() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("u")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst().first())
        XCTAssertEqual(entries.sorted(), ["mock/user", "user"])
        XCTAssertEqual(vm.suggestion, "user")
    }

    func testNoRefreshOnAcceptingSuggestion() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("m")
        vm.autocomplete("mock/user")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst(1).first())
        XCTAssertEqual(entries.sorted(), ["mock/user"])
        XCTAssertEqual(vm.suggestion, "mock/user")
    }

    func testNoRefreshOnAcceptingSuggestionX() throws {
        let vm = PassViewModel(pass: mockPass)
        let cancellable = vm.$suggestion.sink {
            if let suggestion = $0 {
                vm.autocomplete(suggestion)
            }
        }
        vm.autocomplete("m")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst(1).first())
        XCTAssertEqual(entries.sorted(), ["mock/user"])
//        XCTAssertEqual(vm.suggestion, "mock/user")
        cancellable.cancel()
    }
}
