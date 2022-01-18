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
                    if text.count <= 2 || lastResult.contains(text) {
                        return
                    }
                    do {
                        self.lastResult = try (NSApplication.shared.delegate as! AppDelegate).pass.query(text)
                        if lastResult.count > 0 {
//                            opt = 0
//                            let result = lastResult[opt]
                            DispatchQueue.main.async {
//                                query = result
//                                DispatchQueue.main.async {
//                                    let nsText = result as NSString
//                                    let after = nsText.range(of: text).upperBound
//                                    let range = NSMakeRange(after, nsText.length - after)
//                                    textField.setSelectedRange(range)
//                                }
                            }
                        }
                    } catch {
                        // ignore
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
                            print("submit username \(username )")
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

    func submitText(_ text: String) {
        DispatchQueue.main.async {
            self.myWindow?.close()
            NSApplication.shared.hide(nil)

            PasteUtil.paste(text)
        }
    }

    func submitPassword(_ entry: String) {
        do {
            print("submit entry \(entry)")
            if let pw = try (NSApplication.shared.delegate as! AppDelegate).pass.getLogin(entry: entry) {
                submitText(pw)
            }
        } catch {
            //ignore
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(myWindow: nil)
    }
}
