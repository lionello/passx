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
    static let showFloatingPanel = Self("showFloatingPanel", default: .init(.return, modifiers: [.command, .shift]))
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var newEntryPanel: FloatingPanel!
    var pass: Pass!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        pass = GoPass(wrapper: "/Users/llunesu/.config/gopass/gopass_wrapper.sh")

        createFloatingPanel()
        
        // Center doesn't place it in the absolute center, see the documentation for more details
        newEntryPanel.center()
        
        // Shows the panel and makes it active
        newEntryPanel.orderFront(nil)
        newEntryPanel.makeKey()
        
        KeyboardShortcuts.onKeyUp(for: .showFloatingPanel, action: {
            self.newEntryPanel.orderFront(nil)
            self.newEntryPanel.makeKey()
        })
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Insert code here to tear down your application
    }
    
    private func createFloatingPanel() {
        
        // Create the window and set the content view.
        newEntryPanel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 512, height: 80), backing: .buffered, defer: false)
        
        // Create the SwiftUI view that provides the window contents.
        // I've opted to ignore top safe area as well, since we're hiding the traffic icons
        let contentView = ContentView(myWindow: newEntryPanel)
            .edgesIgnoringSafeArea(.top)
        
        newEntryPanel.title = "Floating Panel Title"
        newEntryPanel.contentView = NSHostingView(rootView: contentView)
    }
}
