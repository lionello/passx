//
//  CopyUtil.swift
//  passx
//
//  Created by Lionello Lunesu on 2022-07-18.
//

import SwiftUI
import UserNotifications

class CopyUtil {

    /// How long a secret stays on the clipboard before it's cleared
    static let clearDelay: Duration = .seconds(45)

    // See http://nspasteboard.org: clipboard managers skip (or hide) items marked with these types
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private init() {}

    /// - Parameter description: shown in the notification instead of `text` (use this for secrets)
    /// - Parameter secret: keep `text` out of clipboard history and Universal Clipboard, and clear it after `clearDelay`
    @MainActor
    static func copyToClipboard(_ text: String, description: String? = nil, secret: Bool = false, pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.prepareForNewContents(with: secret ? .currentHostOnly : [])
        guard pasteboard.setString(text, forType: .string) else {
            debugPrint("NSPasteboard.setString failed")
            return false
        }
        if secret {
            pasteboard.setString("", forType: concealedType)
            pasteboard.setString("", forType: transientType)
            clear(pasteboard, after: clearDelay, ifUnchangedSince: pasteboard.changeCount)
        }
        showBanner(title: "Copied to clipboard", body: description ?? text)
        return true
    }

    /// Clears the pasteboard after `delay`, unless something else was copied in the meantime
    @MainActor
    static func clear(_ pasteboard: NSPasteboard, after delay: Duration, ifUnchangedSince changeCount: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard pasteboard.changeCount == changeCount else { return }
            pasteboard.clearContents()
            debugPrint("cleared secret from clipboard")
        }
    }

    private static func showBanner(title: String, body: String) -> Void {
        let notificationCenter = UNUserNotificationCenter.current();
        notificationCenter.getNotificationSettings { (settings) in
            if settings.authorizationStatus == .authorized {

                let content = UNMutableNotificationContent();
                content.title = title;
                content.body = body;

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false);

                let uuidString = UUID().uuidString;
                let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger);

                // Schedule the request with the system.
                notificationCenter.add(request) { (error) in
                    if let error = error {
                        debugPrint(error.localizedDescription)
                    }
                }
            }
        }
    }
}
