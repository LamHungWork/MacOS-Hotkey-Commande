import Foundation
import os

/// Runs a button's command by the button's id. It knows nothing of hotkeys or windows, so anything
/// that has an id can call it.
final class ScriptRunner {
    private let configManager: ConfigurationManager
    private let loginShellPath = LoginShellPath()

    init(configManager: ConfigurationManager) {
        self.configManager = configManager
    }

    /// Reads the login shell's PATH. Called once, at launch.
    func prepare() {
        loginShellPath.load()
    }

    /// Starts a new run of its own each time, next to any run of the same button still going.
    func run(id: String) {
        guard let shortcut = configManager.getShortcut(id: id) else { return }
        loginShellPath.whenReady { path in
            Self.start(shortcut, path: path)
        }
    }

    /// The command runs inside a small shell of its own that also writes the log, so it goes on, and a
    /// failure is still logged, after the app has quit. Output goes to a file: a pipe would fill up, and
    /// would break when the app quits.
    private static let wrapper = #"""
        out=$(/usr/bin/mktemp -t hotkeycommander 2>/dev/null) || out=/dev/null
        /bin/zsh -c "$1" >"$out" 2>&1
        code=$?
        if [ "$code" -ne 0 ]; then
            /bin/mkdir -p "${3%/*}"
            {
                printf '[%s] %s: exit code %s\n' "$(/bin/date '+%Y-%m-%d %H:%M:%S')" "$2" "$code"
                /bin/cat "$out"
                printf '\n'
            } >>"$3"
        fi
        [ "$out" = /dev/null ] || /bin/rm -f "$out"
        """#

    private static func start(_ shortcut: ShortcutConfig, path: String?) {
        let label = logLabel(of: shortcut)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", wrapper, "sh", shortcut.command, label, AppPaths.scriptLog.path]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        if let path = path {
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = path
            process.environment = environment
        }

        do {
            try process.run()
        } catch {
            Logger.app.error("\(label, privacy: .public) did not start: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func logLabel(of shortcut: ShortcutConfig) -> String {
        return shortcut.key.isEmpty ? shortcut.displayName : "\(shortcut.displayName) (\(shortcut.key.uppercased()))"
    }
}
