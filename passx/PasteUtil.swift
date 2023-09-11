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

    fileprivate static let delay: useconds_t = 22259 // ~22ms

    private init() {}

    static func paste(vk: CGKeyCode, flags: CGEventFlags = CGEventFlags(rawValue: 0)) -> Bool {
        if let event1 = CGEvent(keyboardEventSource: nil, virtualKey: vk, keyDown: true) {
            event1.flags = flags
            event1.post(tap: .cghidEventTap)

            usleep(delay)

            if let event2 = CGEvent(keyboardEventSource: nil, virtualKey: vk, keyDown: false) {
                event2.flags = flags
                event2.post(tap: .cghidEventTap)
            }
            return true
        } else {
            debugPrint("failed to translate VK \(vk)")
            return false
        }
    }

    static func paste(keys: [KeyCode]) {
        keys.forEach {
            _ = paste(vk: $0.vk, flags: $0.flags)
            usleep(delay/10)
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

    static func paste(str: String) -> Bool {
        let utf16Chars = Array(str.utf16)

        if let event1 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: true) {
            event1.flags = .maskNonCoalesced
            event1.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
            event1.post(tap: .cghidEventTap)

            usleep(delay/10)

            if let event2 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: false) {
                event2.flags = .maskNonCoalesced
                event2.post(tap: .cghidEventTap)
            }
            return true
        } else {
            debugPrint("failed to translate VK 0x31")
            return false
        }
    }

    private static func keyCodeToString(_ inputSource: TISInputSource, keyCode: CGKeyCode, eventModifiers: Int) -> String? {
        guard let layoutData = inputSource.getProperty(kTISPropertyUnicodeKeyLayoutData) as! CFData? else { return nil }
        let keyboardLayoutPtr = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var actualStringLength = 0
        var unicodeString: [UniChar] = [0, 0, 0, 0]

        let status = UCKeyTranslate(keyboardLayoutPtr,
                                    keyCode,
                                    UInt16(kUCKeyActionDown),
                                    UInt32(eventModifiers >> 8), // from UCKeyTranslate doc
                                    UInt32(LMGetKbdType()),
                                    0, // kUCKeyTranslateNoDeadKeysMask,
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

    private static var curKeyboardID: String = ""
    private static var dict: [String: KeyCode] = [:]

    private static func charToKeyCode(ch: Character) -> KeyCode? {
        let curKeyboard = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        if curKeyboardID != curKeyboard.id {
            curKeyboardID = curKeyboard.id
            // For every keyCode, find the character(s) with and without SHIFT
            for i in 0..<128 {
                let keyCode = CGKeyCode(i)
                if let str = keyCodeToString(curKeyboard, keyCode: keyCode, eventModifiers: shiftKey) {
                    dict[str] = KeyCode(vk: keyCode, flags: .maskShift)
                }
                if let str = keyCodeToString(curKeyboard, keyCode: keyCode, eventModifiers: 0) {
                    dict[str] = KeyCode(vk: keyCode, flags: CGEventFlags(rawValue: 0))
                }
            }
        }
        return dict[String(ch)]
    }
}

// Excerpt from https://github.com/creasty/Keyboard/blob/master/keyboard/Extensions/TISInputSource.swift
extension TISInputSource {

    func getProperty(_ key: CFString) -> AnyObject? {
        guard let cfType = TISGetInputSourceProperty(self, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(cfType).takeUnretainedValue()
    }

    var id: String {
        return getProperty(kTISPropertyInputSourceID) as! String
    }

}
