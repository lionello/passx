//
//  Doctor.swift
//  passx
//
//  Created by Claude Opus 5.5 on 2026-11-21.
//

import Foundation

/// Startup health check: finds the tools passx depends on and revives a stuck gpg-agent.
enum Doctor {

    /// Tools that must be on the `PATH` (see `GoPassWrapper.processEnvironment`), with the package that provides them
    static let requiredTools = [
        ("gopass-jsonapi", "gopass-jsonapi"),
        ("gpgconf", "gnupg"),
        ("gpg-connect-agent", "gnupg"),
    ]

    /// The agent answers instantly when healthy; this only needs to catch a hang
    static let agentTimeout: Duration = .seconds(5)

    /// Returns a description of every problem that couldn't be repaired; empty when all is well
    static func check() async -> [String] {
        var problems: [String] = []
        for (tool, package) in requiredTools where findExecutable(tool) == nil {
            problems.append("\(tool) not found; install the \(package) package")
        }
        guard problems.isEmpty else { return problems }

        if await !isAgentResponsive() {
            // Killing the agent is harmless: gpg launches a fresh one (and scdaemon) on demand
            debugPrint("gpg-agent unresponsive; restarting gpg-agent and scdaemon")
            _ = await run("gpgconf", ["--kill", "gpg-agent", "scdaemon"])
            if await !isAgentResponsive() {
                problems.append("gpg-agent is not responding, even after a restart. Try: gpgconf --kill all")
            }
        }
        return problems
    }

    static func findExecutable(_ name: String) -> String? {
        let path = GoPassWrapper.processEnvironment()["PATH"] ?? ""
        return path.split(separator: ":")
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func isAgentResponsive() async -> Bool {
        // Starts the agent if it's not running yet, which is fine: passx needs it anyway
        await run("gpg-connect-agent", ["GETINFO version", "/bye"], timeout: agentTimeout) == 0
    }

    /// Runs `tool` and returns its exit status, or nil if it couldn't be started or timed out
    static func run(_ tool: String, _ arguments: [String], timeout: Duration = agentTimeout) async -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [tool] + arguments
        process.environment = GoPassWrapper.processEnvironment()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        var timeoutTask: Task<Bool, Never>?
        let status: Int32? = await withCheckedContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
                timeoutTask = process.terminate(after: timeout)
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: nil)
            }
        }
        timeoutTask?.cancel()
        if await timeoutTask?.value == true {
            return nil
        }
        return status
    }
}
