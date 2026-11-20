//
//  KeyCommandTests.swift
//  passxTests
//

import AppKit
import Testing
@testable import passx

struct KeyCommandTests {

    private func command(_ keyCode: UInt16, _ modifiers: NSEvent.ModifierFlags = [], _ characters: String? = nil) -> KeyCommand? {
        KeyCommand.from(keyCode: keyCode, modifiers: modifiers, characters: characters)
    }

    @Test func arrowsMoveHighlight() {
        #expect(command(126) == .moveUp)
        #expect(command(125) == .moveDown)
        #expect(command(125, .shift) == nil)
    }

    @Test func emacsStyleNavigation() {
        #expect(command(45, .control, "n") == .moveDown)
        #expect(command(35, .control, "p") == .moveUp)
    }

    @Test func returnPicksField() {
        #expect(command(36) == .perform(EntryAction(field: .password, copy: false)))
        #expect(command(76) == .perform(EntryAction(field: .password, copy: false)))
        #expect(command(36, .command) == .perform(EntryAction(field: .username, copy: false)))
        #expect(command(36, .option) == .perform(EntryAction(field: .current_totp, copy: false)))
        #expect(command(36, [.command, .option]) == nil)
        #expect(command(36, .control) == nil)
    }

    @Test func shiftCopiesInsteadOfPasting() {
        #expect(command(36, .shift) == .perform(EntryAction(field: .password, copy: true)))
        #expect(command(36, [.shift, .command]) == .perform(EntryAction(field: .username, copy: true)))
        #expect(command(36, [.shift, .option]) == .perform(EntryAction(field: .current_totp, copy: true)))
    }

    @Test func commandDigitSelectsRow() {
        #expect(command(18, .command, "1") == .selectRow(0))
        #expect(command(25, .command, "9") == .selectRow(8))
        #expect(command(29, .command, "0") == nil)
        #expect(command(18, [], "1") == nil)
    }

    @Test func escapeDismisses() {
        #expect(command(53) == .dismiss)
    }

    @Test func ignoresDeviceDependentFlags() {
        // Keypad/function flags must not break the mapping
        #expect(command(126, [.numericPad, .function]) == .moveUp)
    }

    @Test func plainTypingIsNotIntercepted() {
        #expect(command(0, [], "a") == nil)
        #expect(command(8, .command, "c") == nil)
    }
}
