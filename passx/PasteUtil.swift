//
//  Paste.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//  From https://www.hackingwithswift.com/forums/macos/how-can-i-programmatically-enter-text-to-an-arbitrary-application-first-responder/1612
//

import Foundation
import Carbon

class PasteUtil {

    private init() {}

    static func paste(vk: CGKeyCode, flags: CGEventFlags = CGEventFlags(rawValue: 0)) {
        let event1 = CGEvent(keyboardEventSource: nil, virtualKey: vk, keyDown: true)
        event1?.flags = flags
//        event1?.flags = .maskNonCoalesced
//        event1?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        event1?.post(tap: .cghidEventTap)

        let event2 = CGEvent(keyboardEventSource: nil, virtualKey: vk, keyDown: false)
        event1?.flags = flags
//        event2?.flags = .maskNonCoalesced
        event2?.post(tap: .cghidEventTap)
    }

    static func paste(keys: [KeyCode]) {
        keys.forEach {
            paste(vk: $0.vk, flags: $0.flags)
        }
    }

    static func stringToKeyCodes(_ str: String) throws -> [KeyCode] {
        try str.map {
            guard let kc = charToKeyCode(ch: $0) else {
                throw PassError.err(msg: "Don't know how to press '\($0)'")
            }
            return kc
        }
    }

    static func paste(str: String) {
        let utf16Chars = Array(str.utf16)
        let event1 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: true);
        event1?.flags = .maskNonCoalesced
        event1?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        event1?.post(tap: .cghidEventTap)

        let event2 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: false);
        event2?.flags = .maskNonCoalesced
        event2?.post(tap: .cghidEventTap)
    }

    private static func keyCodeToString(keyCode: CGKeyCode, eventModifiers: Int) -> String? {
        let curKeyboard = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let rawLayoutData = TISGetInputSourceProperty(curKeyboard, kTISPropertyUnicodeKeyLayoutData)
        let layoutData      = unsafeBitCast(rawLayoutData, to: CFData.self)
        let keyboardLayoutPtr = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var actualStringLength = 0
        var unicodeString: [UniChar] = [0, 0, 0, 0]

        let status = UCKeyTranslate(keyboardLayoutPtr,
                                    keyCode,
                                    UInt16(kUCKeyActionDown),
                                    UInt32(eventModifiers >> 8), // from UCKeyTranslate doc
                                    UInt32(LMGetKbdType()),
                                    0,
                                    &deadKeyState,
                                    unicodeString.count,
                                    &actualStringLength,
                                    &unicodeString)

        if status != noErr {
            return nil
        }
        return NSString(characters: unicodeString, length: actualStringLength) as String
    }

    struct KeyCode {
        var vk: CGKeyCode
        var flags: CGEventFlags
    }

    private static var dict: [String: KeyCode] = [:]

    private static func charToKeyCode(ch: Character) -> KeyCode? {
        if dict.isEmpty {
            // For every keyCode, find the character(s) with and without SHIFT
            for i in 0..<128 {
                let keyCode = CGKeyCode(i)
                if let str = keyCodeToString(keyCode: keyCode, eventModifiers: 0) {
                    dict[str] = KeyCode(vk: keyCode, flags: CGEventFlags(rawValue: 0))
                }
                if let str = keyCodeToString(keyCode: keyCode, eventModifiers: shiftKey) {
                    dict[str] = KeyCode(vk: keyCode, flags: .maskShift)
                }
            }
        }
        return dict[String(ch)]
    }
}
