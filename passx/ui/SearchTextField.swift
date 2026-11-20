//
//  SearchTextField.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-31.
//  From https://www.fullstackstanley.com/articles/replicating-the-macos-search-textfield-in-swiftui/

import Foundation
import SwiftUI

struct SearchTextField: View {
    @Binding var query: String
    @State var isFocused: Bool = false
    var placeholder: String = "Search..."
    /// Optional image shown in place of the magnifying glass (e.g. the app icon)
    var icon: NSImage? = nil
    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .padding(.leading, 10)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "magnifyingglass").resizable().aspectRatio(contentMode: .fill)
                    .frame(width:12, height: 12)
                    .padding(.leading, 8)
                    .opacity(0.8)
            }

            TextField(placeholder, text: $query, onEditingChanged: { (editingChanged) in
                if editingChanged {
                    self.isFocused = true
                } else {
                    self.isFocused = false
                }
            })
                .textFieldStyle(PlainTextFieldStyle())
                .font(.title2)

            if query != "" {
                Button(action: {
                    self.query = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:14, height: 14)
                        .padding(.trailing, 6)
                        .opacity(0.5)
                }
                .buttonStyle(.plain)
                .opacity(self.query == "" ? 0 : 0.5)
            }
        }
    }
}
