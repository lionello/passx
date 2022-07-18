//
//  CopyUtil.swift
//  passx
//
//  Created by Lionello Lunesu on 2022-07-18.
//

import SwiftUI
import UserNotifications

class CopyUtil {

    private init() {}

    static func copyToClipboard(_ text: String) -> Bool {
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(text, forType: .string) {
            showBanner(title: "Copied to clipboard", body: text)
            return true
        } else {
            debugPrint("NSPasteboard.general.setString failed")
            return false
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
