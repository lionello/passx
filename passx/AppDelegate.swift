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
    static let showFloatingPanel = Self("showFloatingPanel", default: .init(.f12, modifiers: [.command]))
}

class AppDelegate: NSObject, NSApplicationDelegate {

    static let HOME = ProcessInfo.processInfo.environment["HOME"]!

    var newEntryPanel: FloatingPanel!
    var pass: PassProtocol!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        pass = GoPassWrapper(wrapper: "\(AppDelegate.HOME)/.config/gopass/gopass_wrapper.sh")

        createFloatingPanel()
        
        // Center doesn't place it in the absolute center, see the documentation for more details
        newEntryPanel.center()
        
        // Shows the panel and makes it active
        newEntryPanel.makeKeyAndOrderFront(nil)

        KeyboardShortcuts.setShortcut(.init(.f12, modifiers: [.command]), for: .showFloatingPanel)
        KeyboardShortcuts.onKeyUp(for: .showFloatingPanel, action: {
            self.newEntryPanel.makeKeyAndOrderFront(nil)
        })
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Insert code here to tear down your application
    }
    
    private func createFloatingPanel() {
        
        // Create the window and set the content view.
        newEntryPanel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 512, height: 200), backing: .buffered, defer: false)
        
        // Create the SwiftUI view that provides the window contents.
        // I've opted to ignore top safe area as well, since we're hiding the traffic icons
        let contentView = ContentView(myWindow: newEntryPanel)
            .edgesIgnoringSafeArea(.top)
        
        newEntryPanel.title = "Floating Panel Title"
        newEntryPanel.contentView = NSHostingView(rootView: contentView)
    }
}
