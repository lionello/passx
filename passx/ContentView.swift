//
//  ContentView.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import SwiftUI

struct ContentView: View {
    let myWindow:NSWindow?

    @State
    private var lastResult: [String] = []

    @State
    private var opt: Int = -1

    @State
    private var query: String = "zc.qq.com"

    var body: some View {
        SearchTextField(query: $query)
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
                        opt = 0
                        let result = lastResult[opt]
                        DispatchQueue.main.async {
                            query = result
                            DispatchQueue.main.async {
                                let nsText = result as NSString
                                let after = nsText.range(of: text).upperBound
                                let range = NSMakeRange(after, nsText.length - after)
                                textField.setSelectedRange(range)
                            }
                        }
                    }
                } catch {
                    // ignore
                }
            }
//            .textSelection(.enabled)
            .onSubmit {
                do {
                    if let pw = try (NSApplication.shared.delegate as! AppDelegate).pass.getLogin(entry: query) {
                        self.myWindow?.close()
                        NSApplication.shared.hide(nil)
                        
                        PasteUtil().paste(pw)
                    }
                } catch {
                    //ignore
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(myWindow: nil)
    }
}
