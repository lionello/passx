//
//  main.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//  From https://sarunw.com/posts/how-to-create-macos-app-without-storyboard/
//

import Foundation
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
