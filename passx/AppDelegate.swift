//
//  AppDelegate.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import Cocoa
import SwiftUI
import KeyboardShortcuts

// From https://www.markusbodner.com/til/2021/02/08/use-global-keyboard-hotkey-to-show/hide-a-window-using-swift/
extension KeyboardShortcuts.Name {
    // **NOTE**: It is not recommended to set a default keyboard shortcut. Instead opt to show a setup on first app-launch to let the user define a shortcut
    static let showFloatingPanel = Self("showFloatingPanel", default: .init(.backslash, modifiers: [.command, .option]))
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    static let HOME = ProcessInfo.processInfo.environment["HOME"]!
    
    var newEntryPanel: FloatingPanel!
    var pass: PassProtocol!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // FIXME: make this configurable
        pass = GoPassWrapper(wrapper: "\(AppDelegate.HOME)/.config/gopass/gopass_wrapper.sh")
        
        createFloatingPanel()
        
        // Center doesn't place it in the absolute center, see the documentation for more details
        newEntryPanel.center()
        
        // Shows the panel and makes it active
        newEntryPanel.makeKeyAndOrderFront(nil)

        KeyboardShortcuts.setShortcut(.init(.backslash, modifiers: [.command, .option]), for: .showFloatingPanel)
        KeyboardShortcuts.onKeyUp(for: .showFloatingPanel, action: {
            self.newEntryPanel.makeKeyAndOrderFront(nil)
        })

        // Create the popover
//        let popover = NSPopover()
//        popover.contentSize = NSSize(width: 400, height: 400)
//        popover.behavior = .transient
//        popover.contentViewController = NSHostingController(rootView: newEntryPanel.contentView)
//        self.popover = popover
    }

//    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
//      let menu = NSMenu()
//        menu.addItem(withTitle: "Select All",
//                     action: #selector(NSTextField.selectAll(_:)), keyEquivalent: "a")
//      return menu
//    }

    private func createFloatingPanel() {
        // Create the window and set the content view.
        newEntryPanel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 512, height: 200), backing: .buffered, defer: false)
        
        // Create the SwiftUI view that provides the window contents.
        // I've opted to ignore top safe area as well, since we're hiding the traffic icons
        let contentView = ContentView(myWindow: newEntryPanel)
            .environmentObject(PassViewModel(pass: pass))
            .edgesIgnoringSafeArea(.top)

        newEntryPanel.title = "Pass Search"
        newEntryPanel.contentView = NSHostingView(rootView: contentView)
    }
}
