//
//  PassProtocol.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import Foundation

enum PassError : Error {
    case err(msg: String?)
    case notImplemented
    case invalidNativeMessage
    case timedOut(command: String, after: Duration)
}

extension PassError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .err(let msg):
            return msg
        case .notImplemented:
            return "Not implemented"
        case .invalidNativeMessage:
            return "Invalid native message"
        case .timedOut(let command, let after):
            return "\(command) did not respond within \(after.formatted(.units(allowed: [.seconds]))). Is your security key plugged in? Restarting gpg-agent may help: gpgconf --kill gpg-agent scdaemon"
        }
    }
}

enum PassField : String {
    case password
    case username
    case current_totp
    case url

    fileprivate func prefixes() -> [String] {
        switch self {
        case .password:
            return [""] // matches all lines
        case .username:
            return ["login:", "username:", "user:"] // TODO: require a space after :?
        case .current_totp:
            return ["totp:", "otpauth:"]
        case .url:
            return ["https:", "url:"]
        }
    }

    func isMatch(_ line: String) -> Bool {
        return prefixes().contains(where: line.hasPrefix)
    }
}

/// Long enough to type a passphrase into pinentry or touch a security key, short enough to recover from a stuck scdaemon
let defaultPassTimeout: Duration = .seconds(60)

extension Process {
    /// Terminates the process if it's still running after `timeout`.
    /// Cancel the returned task once the process is done; its value tells whether the timeout fired.
    func terminate(after timeout: Duration) -> Task<Bool, Never> {
        Task {
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return false
            }
            guard isRunning else { return false }
            debugPrint("terminating", executableURL?.lastPathComponent ?? "process", "after", timeout)
            terminate()
            return true
        }
    }
}

protocol PassProtocol {
    func getLogin(entry: String, field: PassField) async throws -> String?
    func query(_ query: String) async throws -> [String]
    func queryHost(_ host: String) async throws -> [String]
}
