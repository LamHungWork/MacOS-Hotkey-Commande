import Cocoa
import Carbon

/// The Activation Hotkey plus a button's key.
class HotkeyManager {
    /// Called with the id of the button whose key was pressed.
    var onHotkey: ((String) -> Void)?

    private static let signature: OSType = 0x484B434D // "HKCM"

    private let configManager: ConfigurationManager
    private var registeredHotkeys: [UInt32: (ref: EventHotKeyRef, shortcutID: String)] = [:]
    private var eventHandler: EventHandlerRef?

    init(configManager: ConfigurationManager) {
        self.configManager = configManager
    }

    deinit {
        stopListening()
    }

    func startListening() {
        // Setup Carbon event handler for hotkey pressed
        setupEventHandler()

        // Register all hotkeys from config
        registerAllHotkeys()
    }

    func stopListening() {
        // Unregister all hotkeys
        unregisterAllHotkeys()

        // Remove event handler
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    func reloadConfiguration() {
        stopListening()
        startListening()
    }

    private func setupEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotkeyID = EventHotKeyID()
                let error = GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                guard error == noErr, hotkeyID.signature == HotkeyManager.signature else {
                    return OSStatus(eventNotHandledErr)
                }

                manager.handleHotkeyPressed(id: hotkeyID.id)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func registerAllHotkeys() {
        // Convert activation modifiers to Carbon format
        var carbonModifiers = UInt32(0)
        for modifier in configManager.getActivationModifiers() {
            switch modifier.lowercased() {
            case "control":
                carbonModifiers |= UInt32(controlKey)
            case "shift":
                carbonModifiers |= UInt32(shiftKey)
            case "command":
                carbonModifiers |= UInt32(cmdKey)
            case "option":
                carbonModifiers |= UInt32(optionKey)
            default:
                break
            }
        }

        // Register each shortcut that has a key
        for (index, shortcut) in configManager.getShortcuts().enumerated() {
            guard let keyCode = Self.keyCode(for: shortcut.key) else {
                continue
            }

            registerHotkey(keyCode: keyCode, modifiers: carbonModifiers, id: UInt32(index + 1), shortcutID: shortcut.id)
        }
    }

    private func registerHotkey(keyCode: Int, modifiers: UInt32, id: UInt32, shortcutID: String) {
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef = hotKeyRef {
            registeredHotkeys[id] = (hotKeyRef, shortcutID)
        }
    }

    private func unregisterAllHotkeys() {
        for (_, hotkey) in registeredHotkeys {
            UnregisterEventHotKey(hotkey.ref)
        }

        registeredHotkeys.removeAll()
    }

    private func handleHotkeyPressed(id: UInt32) {
        guard let hotkey = registeredHotkeys[id] else { return }
        onHotkey?(hotkey.shortcutID)
    }

    /// nil for a character that cannot be a hotkey.
    static func keyCode(for character: String) -> Int? {
        // Map characters to keycodes
        let keyMap: [String: Int] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
            "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
            "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
            "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45,
            "m": 46, ".": 47
        ]

        return keyMap[character.lowercased()]
    }
}
