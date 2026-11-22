import Foundation

/// Where the app keeps its own files. Everything is named after the bundle id, so a test build with
/// its own id never touches the files of the installed app.
enum AppPaths {
    static let bundleID = Bundle.main.bundleIdentifier ?? "HotkeyCommander"

    static var icons: URL {
        return library("Application Support").appendingPathComponent(bundleID).appendingPathComponent("icons")
    }

    static var scriptLog: URL {
        let folder = bundleID == "com.hotkeycommander.app" ? "HotkeyCommander" : bundleID
        return library("Logs").appendingPathComponent(folder).appendingPathComponent("deck.log")
    }

    private static func library(_ folder: String) -> URL {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library").appendingPathComponent(folder)
    }
}
