//
//  FloatingPanel.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//  From https://www.markusbodner.com/til/2021/02/08/create-a-spotlight/alfred-like-window-on-macos-with-swiftui/
//

import Foundation
import SwiftUI

// MARK: - Floating Panel

class FloatingPanel: NSPanel {
  init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {

    // Not sure if .titled does affect anything here. Kept it because I think it might help with accessibility but I did not test that.
    super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView], backing: backing, defer: flag)

    // Set this if you want the panel to remember its size/position
    self.setFrameAutosaveName("passx")

    // Allow the pannel to be on top of almost all other windows
    self.isFloatingPanel = true
    self.level = .floating

    // Allow the pannel to appear in a fullscreen space
    self.collectionBehavior.insert(.fullScreenAuxiliary)

    // While we may set a title for the window, don't show it
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true

    // Since there is no titlebar make the window moveable by click-dragging on the background
    self.isMovableByWindowBackground = true

    // Keep the panel around after closing since I expect the user to open/close it often
    self.isReleasedWhenClosed = false

    // Activate this if you want the window to hide once it is no longer focused
//    self.hidesOnDeactivate = true

    // Hide the traffic icons (standard close, minimize, maximize buttons)
    self.standardWindowButton(.closeButton)?.isHidden = true
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true
  }

  // `canBecomeKey` and `canBecomeMain` are required so that text inputs inside the panel can receive focus
  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }
}

