//
//  AppDelegate.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import Cocoa
import SwiftUI
import KeyboardShortcuts
import UserNotifications

// From https://www.markusbodner.com/til/2021/02/08/use-global-keyboard-hotkey-to-show/hide-a-window-using-swift/
extension KeyboardShortcuts.Name {
    // **NOTE**: It is not recommended to set a default keyboard shortcut. Instead opt to show a setup on first app-launch to let the user define a shortcut
    static let showFloatingPanel = Self("showFloatingPanel", default: .init(.backslash, modifiers: [.command, .option]))
}

class AppDelegate: NSObject, NSApplicationDelegate {

    /// $XDG_CONFIG_HOME defines the base directory relative to which user-specific configuration files should be stored.
    static let XDG_CONFIG_HOME = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
    /// If $XDG_CONFIG_HOME is either not set or empty, a default equal to $HOME/.config should be used.
    static let configPath = XDG_CONFIG_HOME?.isEmpty == false ? XDG_CONFIG_HOME! : "\(HOME!)/.config"
    static let HOME = ProcessInfo.processInfo.environment["HOME"]

    static let defaultWrapperPath = "\(configPath)/gopass/gopass_wrapper.sh"

    var newEntryPanel: FloatingPanel!
    var pass: PassProtocol!
//    var popover: NSPopover!

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        // FIXME: make this configurable
        pass = GoPassWrapper(wrapper: AppDelegate.defaultWrapperPath)
        
        createFloatingPanel()
        
        // Center doesn't place it in the absolute center, see the documentation for more details
//        newEntryPanel.center() no: using setFrameAutosaveName
        
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

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { (granted, error) in
            debugPrint("requestAuthorization -> granted", granted)
        }
    }

//    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
//      let menu = NSMenu()
//        menu.addItem(withTitle: "Select All",
//                     action: #selector(NSTextField.selectAll(_:)), keyEquivalent: "a")
//      return menu
//    }

    @MainActor private func createFloatingPanel() {
        // Create the window and set the content view.
        newEntryPanel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 512, height: 200), backing: .buffered, defer: false)

        // Create the SwiftUI view that provides the window contents.
        // I've opted to ignore top safe area as well, since we're hiding the traffic icons
        let contentView = ContentView(myWindow: newEntryPanel)
            .edgesIgnoringSafeArea(.top)
            .environmentObject(PassViewModel(pass: pass))

        newEntryPanel.title = "Pass Search"
        newEntryPanel.contentView = NSHostingView(rootView: contentView)
    }
}
