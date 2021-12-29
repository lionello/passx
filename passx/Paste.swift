//
//  Paste.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import Foundation

class Paste {
    func paste(_ str: String) {
        let utf16Chars = Array(str.utf16)

        let event1 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: true);
        event1?.flags = .maskNonCoalesced
        event1?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        event1?.post(tap: .cghidEventTap)

        let event2 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: false);
        event2?.flags = .maskNonCoalesced
        event2?.post(tap: .cghidEventTap)
    }
}
