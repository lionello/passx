//
//  ContentView.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import SwiftUI

enum Focusable: Hashable {
    case query
    case result(id: String)
}

struct ContentView: View {
    
    let myWindow: NSWindow?
    @EnvironmentObject var viewModel: PassViewModel

    @State private var query: String = "zc.qq.com"
    @State private var prev: String = ""
//    @State private var lastResult: [String]
    
    @FocusState private var focusField: Focusable?

    var body: some View {
        VStack {
            SearchTextField(query: $query)
                .frame(width: 512, height: 30)
                .onReceive(viewModel.$result) {
                    self.query = $0
                }
                .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeNotification)) {
                    guard let textField = $0.object as? NSTextView else {
                        return
                    }
                    let text = textField.string
                    if text.count <= 1 || self.prev.count >= text.count {
//                        self.prev = text
                    } else {
                        viewModel.updateQuery(text)
//                        if result != text {
//                            self.prev = text
//                            DispatchQueue.main.async {
//                                textField.string = result
//                                let nsText = result as NSString
//                                let after = nsText.range(of: text).upperBound
//                                let range = NSMakeRange(after, nsText.length - after)
//                                textField.setSelectedRange(range)
//                            }
//                        }
                    }
                    self.prev = text
                }
                .onSubmit {
                    submit(query)
                }
                .focused($focusField, equals: .query)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusField = .query//.wrappedValue = true
                    }
                }
            
            let binding = Binding<String?>(
                get: { self.query },
                set: { self.query = $0 ?? "" }
            )
            List(viewModel.lastResult, id: \.self, selection: binding) { str in
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
            debugPrint("submit text \(text)")
            try submitAndClose(text)
        } catch {
            // TODO: show an error message
        }
    }
    
    func submit(_ entry: String, field: PassField = .password) {
        do {
            debugPrint("submit entry \(entry), field \(field)")
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
            .environmentObject(PassViewModel())
    }
}
