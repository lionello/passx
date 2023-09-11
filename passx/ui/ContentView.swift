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
    case entry(id: String)
}

struct Entry: Identifiable {
    let id: String
    let index: Int
}

struct ContentView: View {

    let myWindow: NSWindow?
    @EnvironmentObject var viewModel: PassViewModel

    @State private var input: String = ""
    @State private var textField: NSTextField?
    @State private var textView: NSTextView? // in case we end up with a TextView
    @State private var lastTask: Task<Void, Never>?

    @FocusState private var focusField: Focusable?

    var uiString: String {
        get {
            return textField?.stringValue ?? textView?.string ?? ""
        }
    }

    static let runningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

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
                    guard !ContentView.isDelete(old: input, new: newValue) || viewModel.entries.count == 0 else { return }
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
                        submitPassword(entry: suggestion, addReturn: true, copyTOTP: true)
                    } else {
                        submitPassword(entry: uiString, addReturn: true, copyTOTP: true)
                    }
                }
                .focused($focusField, equals: .query)
                .onAppear {
                    if !ContentView.runningForPreviews {
                        debugPrint("onAppear")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            focusQuery()
                        }
                    }
                }

            let binding = Binding<String?>(
                get: { self.uiString },
                set: { self.input = $0 ?? "" }
            )
            let entries = viewModel.entries.enumerated().map { index, entry in
                Entry(id: entry, index: index)
            }
            List(entries, id: \.id, selection: binding) { pair in
                EntryRow(index: pair.index, entry: pair.id) { entry, submission in
                    switch submission {
                    case .Literal(let string):
                        setText(entry)
                        submitAndClose(text: string)
                        break
                    case .Field(let passField):
                        submitAndClose(entry: entry, field: passField)
                        break
                    }
                }
                .focused($focusField, equals: .entry(id: pair.id))
            }
        }
    }

    private func submitPassword(entry: String, addReturn: Bool, copyTOTP: Bool) -> Void {
        lastTask?.cancel()
        lastTask = Task.init {
            await submitAndCloseAsync(entry: entry, field: .password, addReturn: addReturn)
            if copyTOTP {
                await copyToClipboard(entry: entry, field: .current_totp)
            }
        }
    }

    private static func isDelete(old: String, new: String) -> Bool {
        debugPrint("old", old, "new", new)
        return old.hasPrefix(new) && new.count < old.count
    }

    private func setText(_ text: String) -> Void {
        textView?.string = text
        textField?.stringValue = text
    }

    private func setSuggestion(_ result: String) -> Void {
        setText(result)
        let nsText = result as NSString
        let after = nsText.range(of: self.input).upperBound
        let range = NSMakeRange(after, nsText.length - after)
        textView?.setSelectedRange(range)
        textField?.currentEditor()?.selectedRange = range
    }

    private func focusQuery() -> Void {
        focusField = .query
        textView?.selectAll(self)
        textField?.currentEditor()?.selectAll(self)
    }

    func copyToClipboard(entry: String, field: PassField) async -> Void {
        do {
            debugPrint("copy entry", entry, "field", field)
            if let text = try await viewModel.pass.getLogin(entry: entry, field: field) {
                _ = CopyUtil.copyToClipboard(text)
            }
        }
        catch {
            debugPrint(error.localizedDescription)
        }
    }

    private func _submitAndClose(_ text: String, addReturn: Bool = false) throws {
        let keys = try PasteUtil.stringToKeyCodes(text + (addReturn ? "\r" : ""))
        focusQuery()
        DispatchQueue.main.async {
            self.myWindow?.close()
            NSApplication.shared.hide(nil)
            
            PasteUtil.paste(keys: keys)
        }
    }
    
    func submitAndClose(text: String) -> Void {
        do {
            debugPrint("submit text", text)
            try _submitAndClose(text)
        } catch {
            // TODO: show an error message
            debugPrint(error.localizedDescription)
        }
    }
    
    func submitAndCloseAsync(entry: String, field: PassField, addReturn: Bool = false) async -> Void {
        do {
            debugPrint("submit entry", entry, "field", field)
            if let text = try await viewModel.pass.getLogin(entry: entry, field: field) {
                setText(entry)
                try _submitAndClose(text, addReturn: addReturn)
            }
        } catch {
            // TODO: show an error message
            debugPrint(error.localizedDescription)
        }
    }

    func submitAndClose(entry: String, field: PassField, addReturn: Bool = false) -> Void {
        lastTask?.cancel()
        lastTask = Task.init {
            await submitAndCloseAsync(entry: entry, field: field, addReturn: addReturn)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(myWindow: nil)
            .environmentObject(PassViewModel(pass: MockPass(), entries: ["example.com/username"]))

        ContentView(myWindow: nil)
            .preferredColorScheme(.dark)
            .environmentObject(PassViewModel(pass: MockPass(), entries: ["username"]))
    }
}

extension Array {
    func singleOrNil() -> Element? {
        return count == 1 ? self[0] : nil
    }
}

// From https://www.avanderlee.com/swiftui/conditional-view-modifier/
extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Like `View.keyboardShortcut(_:modifiers)` but with optional `key`
    @ViewBuilder func keyboardShortcut(_ key: KeyEquivalent?, modifiers: EventModifiers = .command) -> some View {
        if let key = key {
            self.keyboardShortcut(key, modifiers: modifiers)
        } else {
            self
        }
    }
}
