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

    static func paste(_ str: String) {
        str.forEach {
            if let p = charToKeyCode(ch: $0) {
                paste(vk: p.vk, flags: p.flags)
            }
        }

//        let utf16Chars = Array(str.utf16)
//        let event1 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: true);
//        event1?.flags = .maskNonCoalesced
//        event1?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
//        event1?.post(tap: .cghidEventTap)
//
//        let event2 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: false);
//        event2?.flags = .maskNonCoalesced
//        event2?.post(tap: .cghidEventTap)
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

    struct Pair {
        var vk: CGKeyCode
        var flags: CGEventFlags
    }

    private static var dict: [String: Pair] = [:]

    private static func charToKeyCode(ch: Character) -> Pair? {
        if dict.isEmpty {
            // For every keyCode, find the character(s) with and without SHIFT
            for i in 0..<128 {
                let keyCode = CGKeyCode(i)
                if let str = keyCodeToString(keyCode: keyCode, eventModifiers: 0) {
                    dict[str] = Pair(vk: keyCode, flags: CGEventFlags(rawValue: 0))
                }
                if let str = keyCodeToString(keyCode: keyCode, eventModifiers: shiftKey) {
                    dict[str] = Pair(vk: keyCode, flags: .maskShift)
                }
            }
        }
        return dict[String(ch)]
    }
}

/*
 NSString* keyCodeToString(CGKeyCode keyCode)
 {
   TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
   CFDataRef uchr =
     (CFDataRef)TISGetInputSourceProperty(currentKeyboard,
                                          kTISPropertyUnicodeKeyLayoutData);
   const UCKeyboardLayout *keyboardLayout =
     (const UCKeyboardLayout*)CFDataGetBytePtr(uchr);

   if(keyboardLayout)
   {
     UInt32 deadKeyState = 0;
     UniCharCount maxStringLength = 255;
     UniCharCount actualStringLength = 0;
     UniChar unicodeString[maxStringLength];

     OSStatus status = UCKeyTranslate(keyboardLayout,
                                      keyCode, kUCKeyActionDown, 0,
                                      LMGetKbdType(), 0,
                                      &deadKeyState,
                                      maxStringLength,
                                      &actualStringLength, unicodeString);

     if (actualStringLength == 0 && deadKeyState)
     {
       status = UCKeyTranslate(keyboardLayout,
                                        kVK_Space, kUCKeyActionDown, 0,
                                        LMGetKbdType(), 0,
                                        &deadKeyState,
                                        maxStringLength,
                                        &actualStringLength, unicodeString);
     }
     if(actualStringLength > 0 && status == noErr)
       return [[NSString stringWithCharacters:unicodeString
                         length:(NSUInteger)actualStringLength] lowercaseString];
   }

   return nil;
 }

 NSNumber* charToKeyCode(const char c)
 {
   static NSMutableDictionary* dict = nil;

   if (dict == nil)
   {
     dict = [NSMutableDictionary dictionary];

     // For every keyCode
     size_t i;
     for (i = 0; i < 128; ++i)
     {
       NSString* str = keyCodeToString((CGKeyCode)i);
       if(str != nil && ![str isEqualToString:@""])
       {
         [dict setObject:[NSNumber numberWithInt:i] forKey:str];
       }
     }
   }

   NSString * keyChar = [NSString stringWithFormat:@"%c" , c];

   return [dict objectForKey:keyChar];
 }
 */

