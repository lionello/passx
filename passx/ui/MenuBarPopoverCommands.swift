//
//  MenuBarPopoverCommands.swift
//  passx
//
//  Created by Lionello Lunesu on 2022-01-23.
//

import SwiftUI

struct MenuBarPopoverCommands: Commands {

    let appDelegate: AppDelegate

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    var body: some Commands {
        CommandMenu("Edit"){ // Doesn't need to be Edit
            Section {
//                Button("Cut") {
//                    appDelegate.contentView.editCut()
//                }.keyboardShortcut(KeyEquivalent("x"), modifiers: .command)
//
//                Button("Copy") {
//                    appDelegate.contentView.editCopy()
//                }.keyboardShortcut(KeyEquivalent("c"), modifiers: .command)
//
//                Button("Paste") {
//                    appDelegate.contentView.editPaste()
//                }.keyboardShortcut(KeyEquivalent("v"), modifiers: .command)

                Button("Select All") {
//                    appDelegate.contentView.editSelectAll()
                }.keyboardShortcut(KeyEquivalent("a"), modifiers: .command)
            }
        }
    }
}
