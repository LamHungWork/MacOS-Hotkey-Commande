import Cocoa

/// The Activation Hotkey as text, and as read from the keyboard.
enum ModifierNames {
    static func text(for modifiers: [String]) -> String {
        let formatted = modifiers.map { modifier -> String in
            switch modifier.lowercased() {
            case "control": return "Control"
            case "shift": return "Shift"
            case "command": return "Command"
            case "option": return "Option"
            default: return modifier.capitalized
            }
        }
        return formatted.joined(separator: " + ")
    }

    static func names(in flags: NSEvent.ModifierFlags) -> [String] {
        var names: [String] = []
        if flags.contains(.control) { names.append("control") }
        if flags.contains(.shift) { names.append("shift") }
        if flags.contains(.command) { names.append("command") }
        if flags.contains(.option) { names.append("option") }
        return names
    }
}
