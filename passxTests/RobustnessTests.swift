//
//  RobustnessTests.swift
//  passxTests
//
//  Created by Claude Opus 5.5 on 2026-11-21.
//

import AppKit
import Foundation
import Testing
@testable import passx

@MainActor
struct ClipboardTests {
    let pasteboard = NSPasteboard.withUniqueName()

    @Test func secretIsConcealed() {
        #expect(CopyUtil.copyToClipboard("hunter2", description: "Password", secret: true, pasteboard: pasteboard))
        #expect(pasteboard.string(forType: .string) == "hunter2")
        #expect(pasteboard.types?.contains(CopyUtil.concealedType) == true)
        #expect(pasteboard.types?.contains(CopyUtil.transientType) == true)
    }

    @Test func nonSecretIsNotConcealed() {
        #expect(CopyUtil.copyToClipboard("alice", pasteboard: pasteboard))
        #expect(pasteboard.types?.contains(CopyUtil.concealedType) == false)
    }

    @Test func clearsWhenUnchanged() async throws {
        pasteboard.clearContents()
        pasteboard.setString("hunter2", forType: .string)
        CopyUtil.clear(pasteboard, after: .milliseconds(50), ifUnchangedSince: pasteboard.changeCount)
        try await Task.sleep(for: .milliseconds(300))
        #expect(pasteboard.string(forType: .string) == nil)
    }

    @Test func keepsWhatTheUserCopiedSince() async throws {
        pasteboard.clearContents()
        pasteboard.setString("hunter2", forType: .string)
        CopyUtil.clear(pasteboard, after: .milliseconds(50), ifUnchangedSince: pasteboard.changeCount)
        pasteboard.clearContents()
        pasteboard.setString("something else", forType: .string)
        try await Task.sleep(for: .milliseconds(300))
        #expect(pasteboard.string(forType: .string) == "something else")
    }
}

struct TimeoutTests {

    @Test func goPassWrapperTimesOut() async {
        let pass = GoPassWrapper(executable: "/bin/sleep", arguments: ["10"], timeout: .milliseconds(300))
        await #expect {
            _ = try await pass.query("x")
        } throws: { error in
            if case PassError.timedOut = error { return true }
            return false
        }
    }

    @Test func gpgPassTimesOut() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let hangingGpg = dir.appendingPathComponent("gpg")
        try "#!/bin/sh\nsleep 10\n".write(to: hangingGpg, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hangingGpg.path)

        let pass = GpgPass(gpg: hangingGpg.path, store: dir.path, timeout: .milliseconds(300))
        await #expect {
            _ = try await pass.getLogin(entry: "x", field: .password)
        } throws: { error in
            if case PassError.timedOut = error { return true }
            return false
        }
    }

    @Test func doctorRunReportsStatusAndTimeout() async {
        #expect(await Doctor.run("true", []) == 0)
        #expect(await Doctor.run("false", []) == 1)
        #expect(await Doctor.run("sleep", ["10"], timeout: .milliseconds(300)) == nil)
    }

    @Test func doctorFindsExecutables() {
        #expect(Doctor.findExecutable("sh") != nil)
        #expect(Doctor.findExecutable("no-such-tool-\(UUID().uuidString)") == nil)
    }
}
