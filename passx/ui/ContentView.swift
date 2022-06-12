//
//  ContentView.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import SwiftUI
import Introspect

enum Focusable: Hashable {
    case query
    case result(id: String)
}

struct ContentView: View {
    
    let myWindow: NSWindow?
    @EnvironmentObject var viewModel: PassViewModel

    @State private var input: String = ""
    @State private var textField: NSTextField?
    @State private var textView: NSTextView? // in case we end up with a TextView

    @FocusState private var focusField: Focusable?

    var uiString: String {
        get {
            return textField?.stringValue ?? textView?.string ?? ""
        }
    }

    var body: some View {
        VStack {
            SearchTextField(query: $input)
                .introspectTextView {
                    self.textView = $0
                }
                .introspectTextField {
                    self.textField = $0
                }
                .onChange(of: input) { [input] newValue in
                    guard !ContentView.isDelete(old: input, new: newValue) else { return }
                    self.viewModel.autocomplete(newValue)
                }
                .frame(width: 512, height: 30)
                .onReceive(viewModel.$suggestion) {
                    if let result = $0 {
                        // Only replace the current query if the suggestion is longer than the query
                        if result.count > self.input.count && result.hasPrefix(self.input) {
                            setSuggestion(result)
                        }
                    }
                }
                .onSubmit {
                    if let suggestion = viewModel.entries.singleOrNil() {
                        submit(entry: suggestion, addReturn: true)
                    } else {
                        submit(entry: uiString, addReturn: true)
                    }
                }
                .focused($focusField, equals: .query)
                .onAppear {
                    debugPrint("onAppear")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusQuery()
                    }
                }

            let binding = Binding<String?>(
                get: { self.uiString },
                set: { self.input = $0 ?? "" }
            )
            List(viewModel.entries, id: \.self, selection: binding) { str in
                HStack {
                    if let slash = str.lastIndex(of: "/") {
                        let path = ..<slash
                        let username = String(str[str.index(after: slash)...])
                        Text(String(str[path]))
                        Button(username) {
                            setText(str)
                            submit(text: username)
                        }
                    } else {
                        Button(str) {
                            setText(str)
                            submit(text: str)
                        }
                    }
                    Button("●●●") {
                        submit(entry: str)
                    }
                    Menu("...") {
                        Button("Username") {
                            submit(entry: str, field: .username)
                        }
                        Button("TOTP") {
                            submit(entry: str, field: .current_totp)
                        }
                    }
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                .focused($focusField, equals: .result(id: str))
            }
        }
    }

    private static func isDelete(old: String, new: String) -> Bool {
        debugPrint("old", old, "new", new)
        return old.hasPrefix(new) && new.count < old.count
    }

    private func setText(_ text: String) {
        textView?.string = text
        textField?.stringValue = text
    }

    private func setSuggestion(_ result: String) {
        setText(result)
        let nsText = result as NSString
        let after = nsText.range(of: self.input).upperBound
        let range = NSMakeRange(after, nsText.length - after)
        textView?.setSelectedRange(range)
        textField?.currentEditor()?.selectedRange = range
    }

    private func focusQuery() {
        focusField = .query
        textView?.selectAll(self)
        textField?.currentEditor()?.selectAll(self)
    }
    
    func submitAndClose(_ text: String, addReturn: Bool = false) throws {
        let keys = try PasteUtil.stringToKeyCodes(text + (addReturn ? "\r" : ""))
        focusQuery()
        DispatchQueue.main.async {
            self.myWindow?.close()
            NSApplication.shared.hide(nil)
            
            PasteUtil.paste(keys: keys)
        }
    }
    
    func submit(text: String) {
        do {
            debugPrint("submit text", text)
            try submitAndClose(text)
        } catch {
            // TODO: show an error message
            debugPrint(error.localizedDescription)
        }
    }
    
    func submit(entry: String, field: PassField = .password, addReturn: Bool = false) {
        do {
            debugPrint("submit entry", entry, "field", field)
            if let pw = try viewModel.pass.getLogin(entry: entry, field: field) {
                setText(entry)
                try submitAndClose(pw, addReturn: addReturn)
            }
        } catch {
            // TODO: show an error message
            debugPrint(error.localizedDescription)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(myWindow: nil)
            .environmentObject(PassViewModel(pass: MockPass(), entries: ["a/b"]))

        ContentView(myWindow: nil)
            .preferredColorScheme(.dark)
            .environmentObject(PassViewModel(pass: MockPass(), entries: ["a"]))
    }
}

extension Array {
    func singleOrNil() -> Element? {
        return count == 1 ? self[0] : nil
    }
}
