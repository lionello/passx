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
import ApplicationServices

// From https://www.markusbodner.com/til/2021/02/08/use-global-keyboard-hotkey-to-show/hide-a-window-using-swift/
extension KeyboardShortcuts.Name {
    // **NOTE**: It is not recommended to set a default keyboard shortcut. Instead opt to show a setup on first app-launch to let the user define a shortcut
    static let showFloatingPanel = Self("showFloatingPanel", default: .init(.backslash, modifiers: [.command, .option]))
}

class AppDelegate: NSObject, NSApplicationDelegate {

    static let HOME = ProcessInfo.processInfo.environment["HOME"]!
    /// $XDG_CONFIG_HOME defines the base directory relative to which user-specific configuration files should be stored.
    static let XDG_CONFIG_HOME = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
    /// If $XDG_CONFIG_HOME is either not set or empty, a default equal to $HOME/.config should be used.
    static let configPath = XDG_CONFIG_HOME?.isEmpty == false ? XDG_CONFIG_HOME! : "\(HOME)/.config"

    static let defaultWrapperPath = "\(configPath)/gopass/gopass_wrapper.sh"

    var newEntryPanel: FloatingPanel!
    var pass: PassProtocol!
//    var popover: NSPopover!

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        // FIXME: make this configurable
        pass = GoPassWrapper(wrapper: AppDelegate.defaultWrapperPath)
        
        // Set up the application menu
        setupMenuBar()
        
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

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            debugPrint("Accessibility permission not granted — keypress simulation will not work")
        }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { (granted, error) in
            debugPrint("requestAuthorization -> granted", granted)
        }
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

//        menu.addItem(withTitle: "Select All",
//                     action: #selector(NSTextField.selectAll(_:)), keyEquivalent: "a")

        // Get the version number from the Info.plist
        if let versionNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            // Create a new menu item
            let versionMenuItem = NSMenuItem()
            // Set the title of the menu item to the version number
            versionMenuItem.title = "Version \(versionNumber)"
            // Add the menu item to the dock menu
            menu.addItem(versionMenuItem)
        }

        return menu
    }

    @MainActor private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Edit Menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        NSApplication.shared.mainMenu = mainMenu
    }

    @MainActor private func createFloatingPanel() {
        // Create the window and set the content view.
        newEntryPanel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 512, height: 200), backing: .buffered, defer: false)

        // Create the SwiftUI view that provides the window contents.
        // I've opted to ignore top safe area as well, since we're hiding the traffic icons
        let contentView = ContentView(myWindow: newEntryPanel)
            .edgesIgnoringSafeArea(.top)
            .environmentObject(PassViewModel(pass: pass))

//        newEntryPanel.title = "Pass Search"
//        newEntryPanel.Hi
        newEntryPanel.contentView = NSHostingView(rootView: contentView)
    }
}
