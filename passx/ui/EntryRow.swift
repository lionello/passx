//
//  EntryRow.swift
//  passx
//
//  Created by Lionello Lunesu on 2022-07-15.
//

import SwiftUI

/// What to do with a field of an entry: type it into the previous app, or put it on the clipboard
struct EntryAction: Equatable {
    let field: PassField
    let copy: Bool
}

struct EntryRow: View {

    let index: Int
    let entry: String
    let isHighlighted: Bool
    let perform: (String, EntryAction) -> Void

    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    var body: some View {
        HStack(spacing: 8) {
            // Show the site (as a link, if it looks like one) and the username
            let slash = entry.lastIndex(of: "/")
            let username = slash.map { String(entry[entry.index(after: $0)...]) } ?? entry
            if let slash = slash {
                let site = String(entry[..<slash])
                if let match = EntryRow.linkDetector?.firstMatch(in: site, options: [], range: NSRange(location: 0, length: (site as NSString).length)),
                   let url = match.url {
                    Link(site, destination: url)
                } else {
                    Text(site)
                        .foregroundColor(.secondary)
                }
            }
            Text(username)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer(minLength: 8)

            // ⌘1…⌘9 highlights a row directly
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                perform(entry, EntryAction(field: .username, copy: false))
            } label: {
                Image(systemName: "person")
            }
            .help("Paste username (⌘↩)")
            .accessibilityLabel("Paste username")

            Button {
                perform(entry, EntryAction(field: .password, copy: false))
            } label: {
                Image(systemName: "key")
            }
            .help("Paste password (↩)")
            .accessibilityLabel("Paste password")

            Menu {
                Button("Paste Username") { perform(entry, EntryAction(field: .username, copy: false)) }
                Button("Paste Password") { perform(entry, EntryAction(field: .password, copy: false)) }
                Button("Paste One-Time Code") { perform(entry, EntryAction(field: .current_totp, copy: false)) }
                Divider()
                Button("Copy Username") { perform(entry, EntryAction(field: .username, copy: true)) }
                Button("Copy Password") { perform(entry, EntryAction(field: .password, copy: true)) }
                Button("Copy One-Time Code") { perform(entry, EntryAction(field: .current_totp, copy: true)) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More actions")
            .accessibilityLabel("More actions")
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHighlighted ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

struct EntryRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            EntryRow(index: 0, entry: "username", isHighlighted: false) { _, _ in }
            EntryRow(index: 1, entry: "example.com/username", isHighlighted: true) { _, _ in }
            EntryRow(index: 9, entry: "example.com/username", isHighlighted: false) { _, _ in }
        }
        .frame(width: 512)
    }
}
