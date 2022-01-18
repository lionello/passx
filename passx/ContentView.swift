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

    @State private var lastResult: [String] = []

//    @State
//    private var opt: Int = -1

    @State
    private var query: String = "zc.qq.com"

    @FocusState private var focusField: Focusable?

    var body: some View {
        VStack {
            SearchTextField(query: $query)
                .frame(width: 512, height: 30)
                .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeNotification)) {
                    guard let textField = $0.object as? NSTextView else {
                        return
                    }
                    let text = textField.string
                    if text.count <= 1 {
                        return
                    }
                    if let result = self.lastResult.first(where: { $0.starts(with: text) }) {
                        DispatchQueue.main.async {
                            self.query = result
                            DispatchQueue.main.async {
                                let nsText = result as NSString
                                let after = nsText.range(of: text).upperBound
                                let range = NSMakeRange(after, nsText.length - after)
                                textField.setSelectedRange(range)
                            }
                        }
                    } else {
                        do {
                            self.lastResult = try (NSApplication.shared.delegate as! AppDelegate).pass.query(text)
                        } catch {
                            // ignore
                        }
                    }
                }
                .onSubmit {
                    submitPassword(query)
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
            List(lastResult, id: \.self, selection: binding) { str in
                HStack {
                    if let slash = str.lastIndex(of: "/") {
                        let path = ..<slash
                        let username = String(str[str.index(after: slash)...])
                        Text(String(str[path]))
                        Button(username) {
                            submitText(username)
                        }
                    } else {
                        Text(str)
                    }
                    Button("●●●") {
                        submitPassword(str)
                    }
                }
                .focused($focusField, equals: .result(id: str))
            }
//            .onMoveCommand { (direction) in
//                switch direction {
//                case .down:
//                    self.opt += 1
//                case .up:
//                    self.opt += 1
//                }
//            }
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

    func submitText(_ text: String) {
        do {
            print("submit text \(text)")
            try submitAndClose(text)
        } catch {
            // TODO: show an error message
        }
    }

    func submitPassword(_ entry: String) {
        do {
            print("submit entry \(entry)")
            if let pw = try (NSApplication.shared.delegate as! AppDelegate).pass.getLogin(entry: entry) {
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
    }
}
