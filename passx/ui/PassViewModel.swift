//
//  PassViewModel.swift
//  passx
//
//  Created by Lionello Lunesu on 2022-01-27.
//

import Foundation

final class PassViewModel : ObservableObject {

    let pass: PassProtocol

    init(pass: PassProtocol) {
        self.pass = pass
    }

    convenience init() {
        self.init(pass: MockPass())
    }

    @Published private(set) var result: String = ""
    @Published private(set) var lastResult: [String] = []

    private func autocomplete(text: String, lastResult: [String]) {
        if let result = lastResult.first(where: { $0.starts(with: text) }) {
            if result != self.result {
                DispatchQueue.main.async {
                    self.result = result
                }
            }
        }
    }

    func updateQuery(_ text: String) {
        debugPrint("text ", text)
        //        debugPrint("prev ", prev)
        //        if text.count <= 1 || self.prev.count >= text.count {
        //            self.prev = text
        //            return nil
        //        }
        self.autocomplete(text: text, lastResult: self.lastResult)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // TODO: sort by LRU to ensure last used ones are first
                let result = try self.pass.query(text)
                DispatchQueue.main.async {
                    self.lastResult = result
                }
                self.autocomplete(text: text, lastResult: result)
            } catch {
                // ignore
            }
        }
    }
}
