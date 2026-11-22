import Foundation
import os

/// The PATH a new Terminal window has, read once from a login and interactive shell. An app started by
/// macOS only gets the system PATH, where node, pnpm, brew, bun and the like are not found.
final class LoginShellPath {
    private let queue = DispatchQueue(label: "login-shell-path", qos: .userInitiated)
    private var value: String?

    func load() {
        queue.async { self.value = Self.read() }
    }

    /// Calls `body` once the PATH has been read, in the order the calls were made. nil means it could
    /// not be read.
    func whenReady(_ body: @escaping (String?) -> Void) {
        queue.async { body(self.value) }
    }

    private static func read() -> String? {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }

        // Written to a file, so whatever the startup files print cannot get mixed into it.
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/zsh")
        shell.arguments = ["-ilc", #"\builtin print -rn -- "$PATH" >| "$1""#, "zsh", output.path]
        shell.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        shell.standardInput = FileHandle.nullDevice
        shell.standardOutput = FileHandle.nullDevice
        shell.standardError = FileHandle.nullDevice

        let finished = DispatchSemaphore(value: 0)
        shell.terminationHandler = { _ in finished.signal() }

        do {
            try shell.run()
        } catch {
            Logger.app.error("login shell did not start: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        // Startup files that never end must not keep every button from running.
        if finished.wait(timeout: .now() + 10) == .timedOut {
            // With whatever it waits for. An interactive shell ignores anything softer.
            kill(-shell.processIdentifier, SIGKILL)
            kill(shell.processIdentifier, SIGKILL)
            Logger.app.error("login shell did not finish in 10 s")
            return nil
        }

        let path = try? String(contentsOf: output, encoding: .utf8)
        return path?.isEmpty == false ? path : nil
    }
}

extension Logger {
    static let app = Logger(subsystem: AppPaths.bundleID, category: "app")
}
