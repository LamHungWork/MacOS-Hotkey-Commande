import Cocoa
import Carbon

class HotkeyManager {
    private var configManager: ConfigurationManager
    private var registeredHotkeys: [UInt32: (EventHotKeyRef, ShortcutConfig)] = [:]
    private var eventHandler: EventHandlerRef?
    private var activeProcess: Process?
    private var currentlyPressedKey: Int?
    private var keyUpMonitor: Any?

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

        // Setup key up monitor for toggle mode (key release)
        setupKeyUpMonitor()
    }

    func stopListening() {
        // Unregister all hotkeys
        unregisterAllHotkeys()

        // Remove event handler
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }

        // Remove key up monitor
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }

        // Stop any active command
        stopCurrentCommand()
    }

    private func setupEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
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

                if error == noErr {
                    manager.handleHotkeyPressed(id: hotkeyID.id)
                }

                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func setupKeyUpMonitor() {
        // Monitor key up events globally for toggle mode
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self = self else { return }

            let keyCode = Int(event.keyCode)

            // If this is the key we're tracking, stop the command
            if self.currentlyPressedKey == keyCode {
                self.stopCurrentCommand()
                self.currentlyPressedKey = nil
            }
        }
    }

    private func registerAllHotkeys() {
        let activationModifiers = configManager.getActivationModifiers()
        let shortcuts = configManager.getShortcuts()

        // Convert activation modifiers to Carbon format
        var carbonModifiers = UInt32(0)
        for modifier in activationModifiers {
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

        // Register each shortcut
        for (index, shortcut) in shortcuts.enumerated() {
            guard let keyCode = characterToKeyCode(shortcut.key) else {
                continue
            }

            let hotkeyID = UInt32(index + 1)
            registerHotkey(keyCode: keyCode, modifiers: carbonModifiers, id: hotkeyID, shortcut: shortcut)
        }
    }

    @discardableResult
    private func registerHotkey(keyCode: Int, modifiers: UInt32, id: UInt32, shortcut: ShortcutConfig) -> Bool {
        let signature = "HKCM" as CFString // HotKeyCommander
        let sigInt = UTGetOSTypeFromString(signature)

        let hotKeyID = EventHotKeyID(signature: sigInt, id: id)
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef = hotKeyRef {
            registeredHotkeys[id] = (hotKeyRef, shortcut)
            return true
        }

        return false
    }

    private func unregisterAllHotkeys() {
        for (_, (hotKeyRef, _)) in registeredHotkeys {
            UnregisterEventHotKey(hotKeyRef)
        }

        registeredHotkeys.removeAll()
    }

    private func handleHotkeyPressed(id: UInt32) {
        guard let (_, shortcut) = registeredHotkeys[id] else {
            return
        }

        // Track which key is pressed for toggle mode
        if let keyCode = characterToKeyCode(shortcut.key) {
            currentlyPressedKey = keyCode
        }

        // Execute the command
        executeCommand(shortcut.command)
    }

    private func executeCommand(_ command: String) {
        stopCurrentCommand() // Stop any existing command

        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]

        // Setup pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            activeProcess = process
        } catch {
            // Failed to execute command
        }
    }

    private func stopCurrentCommand() {
        guard let process = activeProcess, process.isRunning else { return }

        process.terminate()

        // Give it a moment to terminate gracefully
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if process.isRunning {
                process.interrupt()
            }
        }

        activeProcess = nil
    }

    private func characterToKeyCode(_ character: String) -> Int? {
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

    func reloadConfiguration() {
        stopListening()
        startListening()
    }
}
