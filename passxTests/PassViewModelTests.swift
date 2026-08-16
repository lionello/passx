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

    @MainActor func testHappy() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("mo")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst().first())
        XCTAssertEqual(entries, ["mock/user"])
        XCTAssertEqual(vm.suggestion, "mock/user")
    }

    @MainActor func testEntriesMatchesSubstring() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("ock")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst().first())
        XCTAssertEqual(entries, ["mock/user"])
        XCTAssertNil(vm.suggestion)
    }

    @MainActor func testSuggestionMatchesPrefix() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("us")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst().first())
        XCTAssertEqual(entries.sorted(), ["mock/user", "user"])
        XCTAssertEqual(vm.suggestion, "user")
    }

    @MainActor func testNoSuggestionOnBackspace() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("mock")
        let suggestion = try self.awaitPublisher(vm.$suggestion.dropFirst().first())
        XCTAssertEqual(suggestion, "mock/user")
        vm.autocomplete("moc")
//        XCTAssertNil(vm.suggestion) FIXME: should not fire
    }

    @MainActor func testSingleCharacterSearchPopulatesEntries() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("u")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst().first())
        XCTAssertEqual(entries.sorted(), ["mock/user", "user"])
        XCTAssertEqual(vm.suggestion, "user")
    }

    @MainActor func testEmptySearchClearsEntriesAndSuggestion() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("mo")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst().first())
        XCTAssertEqual(entries, ["mock/user"])
        XCTAssertEqual(vm.suggestion, "mock/user")

        vm.autocomplete("")

        XCTAssertEqual(vm.entries, [])
        XCTAssertNil(vm.suggestion)
    }

    @MainActor func testSearchErrorIsPublished() throws {
        let vm = PassViewModel(pass: mockPass)
        vm.autocomplete("error")
        let errorMessage = try self.awaitPublisher(vm.$errorMessage.dropFirst().first())

        XCTAssertEqual(errorMessage, "error")
        XCTAssertEqual(vm.entries, [])
        XCTAssertNil(vm.suggestion)

        vm.dismissError()

        XCTAssertNil(vm.errorMessage)
    }

    @MainActor func testNoRefreshOnAcceptingSuggestion() throws {
        let vm = PassViewModel(pass: mockPass)
        let cancellable = vm.$suggestion.sink {
            if let suggestion = $0 {
                vm.autocomplete(suggestion)
            }
        }
        vm.autocomplete("mo")
        let entries = try self.awaitPublisher(vm.$entries.dropFirst(1).first())
        XCTAssertEqual(entries, ["mock/user"])
        XCTAssertEqual(vm.suggestion, "mock/user")
        cancellable.cancel()
    }
}
