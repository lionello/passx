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

    private static var previousActiveApplication: NSRunningApplication?

    var newEntryPanel: FloatingPanel!
    var pass: PassProtocol!
//    var popover: NSPopover!

    @MainActor static func captureFrontmostApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        guard app.processIdentifier != NSRunningApplication.current.processIdentifier else { return }
        previousActiveApplication = app
        debugPrint("captured previous app", app.localizedName ?? "<unknown>", app.processIdentifier)
    }

    @MainActor static func restorePreviousApplication() {
        guard let app = previousActiveApplication, !app.isTerminated else {
            debugPrint("no previous app to restore")
            return
        }
        debugPrint("restoring previous app", app.localizedName ?? "<unknown>", app.processIdentifier)
        app.activate(options: [])
    }

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        // FIXME: make this configurable
        pass = GoPassWrapper(executable: "gopass-jsonapi", arguments: ["listen"])
        observeActiveApplications()
        
        // Set up the application menu
        setupMenuBar()
        
        createFloatingPanel()
        
        // Center doesn't place it in the absolute center, see the documentation for more details
//        newEntryPanel.center() no: using setFrameAutosaveName
        
        // Shows the panel and makes it active
        AppDelegate.captureFrontmostApplication()
        newEntryPanel.makeKeyAndOrderFront(nil)

        KeyboardShortcuts.setShortcut(.init(.backslash, modifiers: [.command, .option]), for: .showFloatingPanel)
        KeyboardShortcuts.onKeyUp(for: .showFloatingPanel, action: {
            AppDelegate.captureFrontmostApplication()
            self.newEntryPanel.makeKeyAndOrderFront(nil)
        })

        // Create the popover
//        let popover = NSPopover()
//        popover.contentSize = NSSize(width: 400, height: 400)
//        popover.behavior = .transient
//        popover.contentViewController = NSHostingController(rootView: newEntryPanel.contentView)
//        self.popover = popover

        if !CommandLine.arguments.contains("-uitesting") {
            #if !DEBUG
            PasteUtil.requestAccessibilityPermissionIfNeeded()
            #endif

            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert]) { (granted, error) in
                debugPrint("requestAuthorization -> granted", granted)
            }
        }
    }

    @MainActor private func observeActiveApplications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard app.processIdentifier != NSRunningApplication.current.processIdentifier else { return }
            AppDelegate.previousActiveApplication = app
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
        let aboutItem = appMenu.addItem(withTitle: "About \(appName)", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
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

    @objc private func showAboutPanel() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        let gitRef = info["GitRef"] as? String
        let gitCommit = info["GitCommit"] as? String
        let gitDetails: String
        if let gitRef = gitRef, let gitCommit = gitCommit {
            gitDetails = "Git ref: \(gitRef)\nGit commit: \(gitCommit)"
        } else {
            gitDetails = "Git version: \(version)"
        }
        let credits = NSAttributedString(string: gitDetails)

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .version: version,
            .applicationVersion: "Build \(build)",
            .credits: credits,
        ])
    }

    @MainActor private func createFloatingPanel() {
        // Create the window and set the content view.
        newEntryPanel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 512, height: 320), backing: .buffered, defer: false)

        // Create the SwiftUI view that provides the window contents.
        // I've opted to ignore top safe area as well, since we're hiding the traffic icons
        let contentView = ContentView(myWindow: newEntryPanel)
            .edgesIgnoringSafeArea(.top)
            .environmentObject(PassViewModel(pass: pass))

        // The title bar is hidden, but the title still shows in Mission Control and to VoiceOver
        newEntryPanel.title = ContentView.appName
        newEntryPanel.contentView = NSHostingView(rootView: contentView)
    }
}
