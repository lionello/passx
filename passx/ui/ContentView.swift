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
        set(result) {
            textView?.string = result
            textField?.stringValue = result
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
                    submit(self.uiString, addReturn: true)
                }
                .focused($focusField, equals: .query)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusField = .query
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
                            submit(text: username)
                        }
                    } else {
                        Button(str) {
                            submit(text: str)
                        }
                    }
                    Button("●●●") {
                        submit(str)
                    }
                    Menu("...") {
                        Button("Username") {
                            submit(str, field: .username)
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

    private func setSuggestion(_ result: String) {
        let nsText = result as NSString
        let after = nsText.range(of: self.input).upperBound
        let range = NSMakeRange(after, nsText.length - after)
        textView?.setSelectedRange(range)
        textField?.currentEditor()?.selectedRange = range
    }
    
    func submitAndClose(_ text: String, addReturn: Bool = false) throws {
        let keys = try PasteUtil.stringToKeyCodes(text + (addReturn ? "\r" : ""))
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
        }
    }
    
    func submit(_ entry: String, field: PassField = .password, addReturn: Bool = false) {
        do {
            debugPrint("submit entry", entry, "field", field)
            if let pw = try viewModel.pass.getLogin(entry: entry, field: field) {
                try submitAndClose(pw, addReturn: addReturn)
            }
        } catch {
            // TODO: show an error message
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(myWindow: nil)
            .environmentObject(PassViewModel(pass: MockPass()))
    }
}
