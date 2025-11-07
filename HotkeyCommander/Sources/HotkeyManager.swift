import Cocoa
import Carbon

class HotkeyManager {
    private var configManager: ConfigurationManager
    private var currentlyPressedModifiers: NSEvent.ModifierFlags = []
    private var currentlyPressedKey: String?
    private var activeProcess: Process?
    private var eventMonitor: Any?

    init(configManager: ConfigurationManager) {
        self.configManager = configManager
    }

    func startListening() {
        stopListening() // Stop any existing monitor

        // Monitor key down events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    func stopListening() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        stopCurrentCommand()
    }

    private func handleEvent(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleModifierChange(event)
        case .keyDown:
            handleKeyDown(event)
        case .keyUp:
            handleKeyUp(event)
        default:
            break
        }
    }

    private func handleModifierChange(_ event: NSEvent) {
        let oldModifiers = currentlyPressedModifiers
        currentlyPressedModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Check if required modifiers are being released
        if !hasRequiredModifiers() && activeProcess != nil {
            stopCurrentCommand()
            currentlyPressedKey = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard hasRequiredModifiers() else { return }

        // Get the character pressed
        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              characters.count == 1 else { return }

        let key = characters

        // Check if this key has a command configured
        let shortcuts = configManager.getShortcuts()
        guard let shortcut = shortcuts.first(where: { $0.key.lowercased() == key }) else { return }

        // Only start if not already running for this key
        if currentlyPressedKey != key {
            currentlyPressedKey = key
            executeCommand(shortcut.command)
        }
    }

    private func handleKeyUp(_ event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              characters.count == 1 else { return }

        let key = characters

        // If this was the key we were tracking, stop the command
        if currentlyPressedKey == key {
            stopCurrentCommand()
            currentlyPressedKey = nil
        }
    }

    private func hasRequiredModifiers() -> Bool {
        let requiredModifiers = configManager.getActivationModifiers()
        let currentFlags = currentlyPressedModifiers

        var hasControl = false
        var hasShift = false
        var hasCommand = false
        var hasOption = false

        if currentFlags.contains(.control) {
            hasControl = true
        }
        if currentFlags.contains(.shift) {
            hasShift = true
        }
        if currentFlags.contains(.command) {
            hasCommand = true
        }
        if currentFlags.contains(.option) {
            hasOption = true
        }

        // Check if all required modifiers are pressed
        for modifier in requiredModifiers {
            switch modifier.lowercased() {
            case "control":
                if !hasControl { return false }
            case "shift":
                if !hasShift { return false }
            case "command":
                if !hasCommand { return false }
            case "option":
                if !hasOption { return false }
            default:
                break
            }
        }

        // Also check that no extra modifiers are pressed (strict matching)
        let expectedCount = requiredModifiers.count
        var actualCount = 0
        if hasControl { actualCount += 1 }
        if hasShift { actualCount += 1 }
        if hasCommand { actualCount += 1 }
        if hasOption { actualCount += 1 }

        return actualCount == expectedCount
    }

    private func executeCommand(_ command: String) {
        stopCurrentCommand() // Stop any existing command

        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]

        // Setup pipes for output (optional - can help with debugging)
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            activeProcess = process
        } catch {
            print("Failed to execute command: \(error)")
        }
    }

    private func stopCurrentCommand() {
        if let process = activeProcess, process.isRunning {
            process.terminate()
            // Give it a moment to terminate gracefully
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if process.isRunning {
                    process.interrupt()
                }
            }
        }
        activeProcess = nil
    }

    func reloadConfiguration() {
        // Restart listening with new configuration
        startListening()
    }
}
