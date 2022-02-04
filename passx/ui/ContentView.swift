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

    @State private var input: String = "zc.qq.com"
    @State private var textView: NSTextView!
    @State private var textField: NSTextField!

    @FocusState private var focusField: Focusable?

    var body: some View {
        VStack {
            SearchTextField(query: $input)
                .introspectTextView {
                    self.textView = $0
                }
                .introspectTextField {
                    self.textField = $0
                }
                .onChange(of: input) { newValue in
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
                    submit(input)
                }
                .focused($focusField, equals: .query)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusField = .query
                    }
                }
            
            let binding = Binding<String?>(
                get: { self.input },
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
                        Text(str)
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

    private func setSuggestion(_ result: String) {
//        textView.string = result
        textField.stringValue = result
        let nsText = result as NSString
        let after = nsText.range(of: self.input).upperBound
        let range = NSMakeRange(after, nsText.length - after)
//        textView.setSelectedRange(range)
        textField.currentEditor()?.selectedRange = range
    }
    
    func submitAndClose(_ text: String) throws {
        let keys = try PasteUtil.stringToKeyCodes(text)
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
    
    func submit(_ entry: String, field: PassField = .password) {
        do {
            debugPrint("submit entry", entry, "field", field)
            if let pw = try viewModel.pass.getLogin(entry: entry, field: field) {
                try submitAndClose(pw)
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
