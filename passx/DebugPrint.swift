//
//  DebugPrint.swift
//  passx
//
//  Created by Lionello Lunesu on 2022-01-26.
//

public func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    Swift.debugPrint(items, separator: separator, terminator: terminator)
    #endif
}
