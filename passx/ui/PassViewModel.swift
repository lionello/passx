//
//  PassViewModel.swift
//  passx
//
//  Created by Lionello Lunesu on 2022-01-27.
// Inspired by https://gist.github.com/dmytro-anokhin/29875209ec841481e2a0c48d90259534

import Foundation

@MainActor
final class PassViewModel : ObservableObject {

    let pass: PassProtocol

    @Published private(set) var suggestion: String?
    @Published private(set) var entries: [String]

    private var task: Task<Void, Error>?

    init(pass: PassProtocol, entries: [String] = []) {
        self.pass = pass
        self.entries = entries
    }

    func autocomplete(_ text: String) {
        debugPrint("updateQuery text:", text)
        task?.cancel()
        guard !text.isEmpty else {
            self.suggestion = nil
            return
        }

        guard !self.entries.contains(text) else { return }
        let suggested = setSuggestion(text, entries: self.entries)

        guard text.count > 1 else { return }
        task = Task(priority: .userInitiated) {
            // TODO: sort by LRU to ensure last used ones are shown first
            let result = try self.pass.query(text)
            guard !Task.isCancelled else { return }
            
            self.entries = result
            if !suggested {
                guard !result.contains(text) else { return }
                _ = setSuggestion(text, entries: result)
            }
        }
    }

    private func setSuggestion(_ text: String, entries: [String]) -> Bool {
        guard let existingSuggestion = PassViewModel.findSuggestion(text: text, entries: entries) else {
            return false
        }
        self.suggestion = existingSuggestion
        return true
    }

    // Assuming `entries` is sorted by popularity, returns the best suggestion for `text`
    private static func findSuggestion(text: String, entries: [String]) -> String? {
        return entries.first(where: { $0.hasCaseAndDiacriticInsensitivePrefix(text) })
    }
}

extension String {
    func hasCaseAndDiacriticInsensitivePrefix(_ prefix: String) -> Bool {
        return self.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).hasPrefix(prefix)
    }
}
