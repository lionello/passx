//
//  EntryRow.swift
//  passx
//
//  Created by Lionello Lunesu on 2022-07-15.
//

import SwiftUI

enum Submission {
    case Literal(String)
    case Field(PassField)
}

struct EntryRow: View {

    let index: Int
    let entry: String
    let submit: (String,Submission) -> Void

    // Map from index to keyboard shortcut character (note that the tenth row maps to '0')
    static let charForIndex : [Int:Character] = [0: "1", 1: "2", 2: "3", 3: "4", 4: "5", 5: "6", 6: "7", 7: "8", 8: "9", 9: "0"]

    private static let linkDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    var body: some View {
        HStack {
            let char = EntryRow.charForIndex[index]
            let key = char.map { KeyEquivalent($0) }

            // Show link (or text) for the site or app
            let slash = entry.lastIndex(of: "/")
            if let slash = slash {
                let url = entry[..<slash]
                if let match = EntryRow.linkDetector.firstMatch(in: entry, options: [], range: NSRange(..<url.count)) {
                    Link(url, destination: match.url!) // FIXME: force https://
                } else {
                    Text(url)
                }
            }

            // Show button for the username
            let username = slash.map { String(entry[entry.index(after: $0)...]) } ?? entry
            Button {
                submit(entry, .Literal(username))
            } label: {
                Text(username)
                if let char = char {
                    Text("⌥⌘\(char.description)").opacity(0.5)
                }
            }
            .keyboardShortcut(key, modifiers: [.command, .option])

            // Show button for the password
            Button {
                submit(entry, .Field(.password))
            } label: {
                Text("●●●")
                if let char = char {
                    Text("⌘\(char.description)").opacity(0.5)
                }
            }
            .keyboardShortcut(key)

            // Show a context menu for all other options
            Menu("…") {
                Button("Username") {
                    submit(entry, .Field(.username))
                }
                .keyboardShortcut(key, modifiers: [.command, .control])
                Button("TOTP") {
                  submit(entry, .Field(.current_totp))
                }
                .keyboardShortcut(key, modifiers: [.command, .control, .option])
            }
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

struct EntryRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            EntryRow(index: 0, entry: "username") { _, _ in }
            EntryRow(index: 1, entry: "example.com/username") { _, _ in }
            Text("…")
            EntryRow(index: 9, entry: "username") { _, _ in }
            EntryRow(index: 10, entry: "example.com/username") { _, _ in }
        }
    }
}
