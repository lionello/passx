//
//  ContentView.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import SwiftUI
import Introspect
import KeyboardShortcuts

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
    /// Text currently shown in the search field, including any autocompleted suggestion
    @State private var currentText: String = ""
    /// Row picked with the arrow keys or mouse; `nil` means "follow the search text"
    @State private var selectedIndex: Int?
    @State private var keyMonitor: Any?

    @FocusState private var focusField: Focusable?

    var uiString: String {
        get {
            return textField?.stringValue ?? textView?.string ?? ""
        }
    }

    static let runningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    static let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "passx"

    var body: some View {
        VStack(spacing: 0) {
            SearchTextField(query: $input, placeholder: "Search passwords", icon: NSApplication.shared.applicationIconImage)
                .introspectTextView {
                    self.textView = $0
                }
                .introspectTextField {
                    self.textField = $0
                    $0.focusRingType = .none
                }
                .onChange(of: input) { _, newValue in
                    currentText = newValue
                    selectedIndex = nil
                    self.viewModel.autocomplete(newValue)
                }
                .frame(minWidth: 512)
                .frame(height: 52)
                .onReceive(viewModel.$suggestion) {
                    if let result = $0 {
                        // Only replace the current query if the suggestion is longer than the query
                        if result.count > self.input.count && result.hasPrefix(self.input) {
                            setSuggestion(result)
                        }
                    }
                }
                .focused($focusField, equals: .query)
                .onAppear {
                    if !ContentView.runningForPreviews {
                        debugPrint("onAppear")
                        installKeyMonitor()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            focusQuery()
                        }
                    }
                }
                .onDisappear {
                    removeKeyMonitor()
                }

            Divider()

            let entries = viewModel.entries.enumerated().map { index, entry in
                Entry(id: entry, index: index)
            }
            let highlighted = highlightedIndex
            ScrollViewReader { proxy in
                List(entries, id: \.id) { pair in
                    EntryRow(index: pair.index, entry: pair.id, isHighlighted: pair.index == highlighted) { entry, action in
                        perform(action, on: entry)
                    }
                    .onTapGesture {
                        selectedIndex = pair.index
                    }
                }
                .onChange(of: highlighted) { _, index in
                    if let index = index, index < viewModel.entries.count {
                        proxy.scrollTo(viewModel.entries[index])
                    }
                }
            }
            .onReceive(viewModel.$entries) { _ in
                selectedIndex = nil
            }
            .overlay {
                if entries.isEmpty {
                    EmptyState(appName: ContentView.appName, isSearching: !input.isEmpty)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(message: errorMessage) {
                    viewModel.dismissError()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .padding(.top, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Divider()
            FooterBar(appName: ContentView.appName)
        }
        .animation(.easeOut(duration: 0.18), value: viewModel.errorMessage)
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
        currentText = text
    }

    /// The row that ↩ acts on: the one picked with the arrows, else the one matching the search text, else the first
    private var highlightedIndex: Int? {
        let entries = viewModel.entries
        guard !entries.isEmpty else { return nil }
        if let selectedIndex = selectedIndex, selectedIndex < entries.count {
            return selectedIndex
        }
        return entries.firstIndex(of: currentText) ?? 0
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window === myWindow else { return event }
            // Let the input method finish composing (e.g. Japanese/Chinese input) before we steal ↩ or arrows
            if (textField?.currentEditor() as? NSTextView)?.hasMarkedText() == true || textView?.hasMarkedText() == true {
                return event
            }
            guard let command = KeyCommand.from(keyCode: event.keyCode, modifiers: event.modifierFlags, characters: event.charactersIgnoringModifiers) else {
                return event
            }
            handle(command)
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor = keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    private func handle(_ command: KeyCommand) {
        let count = viewModel.entries.count
        switch command {
        case .moveUp:
            if let index = highlightedIndex {
                selectedIndex = max(index - 1, 0)
            }
        case .moveDown:
            if let index = highlightedIndex {
                selectedIndex = min(index + 1, count - 1)
            }
        case .perform(let action):
            // With no results, fall back to treating the search text as the entry name
            let entry = highlightedIndex.map { viewModel.entries[$0] } ?? uiString
            guard !entry.isEmpty else { return }
            perform(action, on: entry, pressReturn: true)
        case .selectRow(let index):
            guard index < count else { return }
            selectedIndex = index
        case .dismiss:
            if !uiString.isEmpty {
                setText("")
                input = ""
            } else {
                closeAndRestore()
            }
        }
    }

    /// `pressReturn` is set for the keyboard (↩ submits the form, like autofill); clicking the key icon only types the password
    private func perform(_ action: EntryAction, on entry: String, pressReturn: Bool = false) {
        setText(entry)
        if action.copy {
            lastTask?.cancel()
            lastTask = Task.init {
                if await copyToClipboard(entry: entry, field: action.field) {
                    closeAndRestore()
                }
            }
            return
        }
        switch action.field {
        case .password:
            // Keep the TOTP handy for 2FA
            submitPassword(entry: entry, addReturn: pressReturn, copyTOTP: true)
        case .username:
            lastTask?.cancel()
            lastTask = Task.init {
                if let username = await username(for: entry) {
                    submitAndClose(text: username)
                }
            }
        default:
            submitAndClose(entry: entry, field: action.field)
        }
    }

    /// The `username:` field of the entry if it has one, else the last path component (pass convention: `site/username`)
    private func username(for entry: String) async -> String? {
        if let username = try? await viewModel.pass.getLogin(entry: entry, field: .username), !username.isEmpty {
            return username
        }
        return entry.split(separator: "/").last.map(String.init)
    }

    private func closeAndRestore() {
        focusQuery()
        myWindow?.close()
        NSApplication.shared.hide(nil)
        AppDelegate.restorePreviousApplication()
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

    @discardableResult
    func copyToClipboard(entry: String, field: PassField) async -> Bool {
        do {
            debugPrint("copy entry", entry, "field", field)
            let text = field == .username ? await username(for: entry) : try await viewModel.pass.getLogin(entry: entry, field: field)
            if let text = text {
                // Never show the password itself in Notification Center
                let secret = field == .password || field == .current_totp
                return CopyUtil.copyToClipboard(text, description: field == .password ? "Password for \(entry)" : nil, secret: secret)
            }
        }
        catch {
            debugPrint(error.localizedDescription)
        }
        return false
    }

    private func _submitAndClose(_ text: String, addReturn: Bool = false) throws {
        let keys = try PasteUtil.stringToKeyCodes(text + (addReturn ? "\r" : ""))
        focusQuery()
        DispatchQueue.main.async {
            self.myWindow?.close()
            NSApplication.shared.hide(nil)
            AppDelegate.restorePreviousApplication()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                PasteUtil.paste(keys: keys)
            }
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

private struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.caption)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            Button {
                _ = CopyUtil.copyToClipboard(message)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// Shown in place of the (empty) result list so the panel is recognizable at a glance
private struct EmptyState: View {
    let appName: String
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text(appName)
                .font(.title2.weight(.semibold))
            Text(isSearching ? "No matching passwords" : "Type to search your password store")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Bottom bar with the app name and the most important keyboard hints
private struct FooterBar: View {
    let appName: String

    var body: some View {
        HStack(spacing: 14) {
            Text(appName)
                .fontWeight(.semibold)
            if let shortcut = KeyboardShortcuts.getShortcut(for: .showFloatingPanel) {
                Text("\(shortcut.description) to open")
            }
            Spacer()
            Text("↩ Password")
            Text("⌘↩ Username")
            Text("⌥↩ Code")
            Text("⇧ Copy")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 26)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(myWindow: nil)
            .environmentObject(PassViewModel(pass: MockPass(), entries: ["example.com/username"]))

        ContentView(myWindow: nil)
            .preferredColorScheme(.dark)
            .environmentObject(PassViewModel(pass: MockPass(), entries: ["username"]))

        ContentView(myWindow: nil)
            .environmentObject(PassViewModel(pass: MockPass()))
    }
}

/// Keyboard commands for the search panel, modeled after Spotlight/Alfred/Raycast/1Password Quick Access:
/// focus stays in the search field, ↑/↓ move the highlight, ↩ acts on the highlighted row.
enum KeyCommand: Equatable {
    case moveUp
    case moveDown
    /// ↩ = password, ⌘↩ = username, ⌥↩ = one-time code; holding ⇧ copies instead of pastes
    case perform(EntryAction)
    /// ⌘1…⌘9: highlight that row, so any ↩ action can follow
    case selectRow(Int)
    /// Esc: clear the search, or close the panel when already empty
    case dismiss

    static func from(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String?) -> KeyCommand? {
        let mods = modifiers.intersection([.command, .option, .control, .shift])
        switch keyCode {
        case 126 where mods.isEmpty: // ↑
            return .moveUp
        case 125 where mods.isEmpty: // ↓
            return .moveDown
        case 36, 76: // Return, keypad Enter
            let copy = mods.contains(.shift)
            switch mods.subtracting(.shift) {
            case []: return .perform(EntryAction(field: .password, copy: copy))
            case .command: return .perform(EntryAction(field: .username, copy: copy))
            case .option: return .perform(EntryAction(field: .current_totp, copy: copy))
            default: return nil
            }
        case 53 where mods.isEmpty: // Esc
            return .dismiss
        default:
            break
        }
        // Emacs-style ⌃N/⌃P, as supported by Spotlight and Raycast
        if mods == .control {
            switch characters {
            case "n": return .moveDown
            case "p": return .moveUp
            default: return nil
            }
        }
        if mods == .command, let characters = characters, let digit = Int(characters), (1...9).contains(digit) {
            return .selectRow(digit - 1)
        }
        return nil
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
