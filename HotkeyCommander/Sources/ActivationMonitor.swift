import Cocoa

/// When the Activation Hotkey counts as held, given the modifiers and keys seen so far.
struct ActivationHold {
    enum Change {
        case none, began, ended
    }

    private let required: CGEventFlags
    private var held: CGEventFlags = []
    private var isActive = false
    /// Another key or modifier joined in: nothing more until the hotkey is released and held again.
    private var isSpent = false

    static let modifiers: CGEventFlags = [.maskControl, .maskShift, .maskCommand, .maskAlternate, .maskSecondaryFn]

    init(required: CGEventFlags) {
        self.required = required
    }

    mutating func modifiersChanged(to flags: CGEventFlags) -> Change {
        held = flags.intersection(Self.modifiers)

        guard !required.isEmpty, held.isSuperset(of: required) else {
            isSpent = false
            return end()
        }

        if held != required {
            isSpent = true
            return end()
        }

        if isSpent || isActive {
            return .none
        }

        isActive = true
        return .began
    }

    mutating func keyPressed() -> Change {
        guard held.isSuperset(of: required) else { return .none }
        isSpent = true
        return end()
    }

    private mutating func end() -> Change {
        guard isActive else { return .none }
        isActive = false
        return .ended
    }
}

/// Watches the keyboard, without taking any event, for the Activation Hotkey being held and let go.
/// Needs the Accessibility permission, and works on its own whenever it is there.
final class ActivationMonitor {
    /// The hotkey is held, with the time of the event that completed it. Returns whether the panel was
    /// shown.
    var onHold: ((TimeInterval) -> Bool)?
    var onEnd: (() -> Void)?

    private var required: CGEventFlags = []
    private var hold = ActivationHold(required: [])
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    /// Runs while the panel is shown.
    private var releaseTimer: Timer?
    private var keyCount: UInt32 = 0

    func start(modifiers: [String]) {
        setModifiers(modifiers)
        keepTapRunning()

        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.keepTapRunning()
        }
        RunLoop.main.add(timer, forMode: .common)

        // Posted on any change in the Accessibility list. A permission taken away and given back within
        // two seconds leaves a tap that looks fine and gets nothing, so it is made anew.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.stopTap()
                self?.keepTapRunning()
            }
        }
    }

    func setModifiers(_ modifiers: [String]) {
        end()
        required = Self.flags(for: modifiers)
        hold = ActivationHold(required: required)
    }

    /// A button's hotkey fired. It ends the hold when the owner pressed it, not when a script sent it.
    func hotkeyPressed() {
        readKeyCount()
    }

    private func end() {
        releaseTimer?.invalidate()
        releaseTimer = nil
        onEnd?()
    }

    private func handle(_ change: ActivationHold.Change, at time: TimeInterval) {
        switch change {
        case .none:
            break
        case .began:
            guard AXIsProcessTrusted() else { return }
            if onHold?(time) == true {
                watchForRelease()
            }
        case .ended:
            end()
        }
    }

    // MARK: - Event tap

    private func keepTapRunning() {
        guard AXIsProcessTrusted() else {
            stopTap()
            return
        }
        if let tap = tap, CFMachPortIsValid(tap), CGEvent.tapIsEnabled(tap: tap) {
            return
        }
        stopTap()
        startTap()
    }

    private func stopTap() {
        if let source = tapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = tap {
            CFMachPortInvalidate(tap)
        }
        tapSource = nil
        tap = nil
    }

    private func startTap() {
        let events: [CGEventType] = [.flagsChanged, .keyDown]
        let mask = events.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

        // Listen-only: the app in use gets every key as usual, and never waits for this app.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                if let userInfo = userInfo {
                    Unmanaged<ActivationMonitor>.fromOpaque(userInfo).takeUnretainedValue().handle(type, event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.tap = tap
        tapSource = source
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        // While the panel is shown, a key sent by a program is a button's script at work. One from the
        // keyboard has no process behind it.
        let isFromProgram = event.getIntegerValueField(.eventSourceUnixProcessID) != 0
        if releaseTimer != nil, isFromProgram, type == .flagsChanged || type == .keyDown {
            return
        }

        switch type {
        case .flagsChanged:
            let time = NSEvent(cgEvent: event)?.timestamp ?? ProcessInfo.processInfo.systemUptime
            handle(hold.modifiersChanged(to: event.flags), at: time)
        case .keyDown:
            handle(hold.keyPressed(), at: 0)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // Not from inside its own callback.
            DispatchQueue.main.async { [weak self] in
                self?.keepTapRunning()
            }
        default:
            break
        }
    }

    // MARK: - While the panel is shown

    /// Under Secure Input (a password field has the focus) the tap gets no key-downs, so the state of
    /// the keyboard is read as well. The delay lets that state catch up with the event that opened the
    /// panel.
    private func watchForRelease() {
        keyCount = Self.keyDownCount()
        let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.readKeyboard()
        }
        timer.fireDate = Date().addingTimeInterval(0.1)
        RunLoop.main.add(timer, forMode: .common)
        releaseTimer = timer
    }

    private func readKeyboard() {
        readKeyCount()

        // Modifiers as the keyboard itself has them, so a script's are left out. The hotkey's own also count
        // as macOS has them, for a hotkey that does not come from the keyboard.
        let pressed = CGEventSource.flagsState(.hidSystemState)
        let known = CGEventSource.flagsState(.combinedSessionState).intersection(required)
        handle(hold.modifiersChanged(to: pressed.union(known)), at: ProcessInfo.processInfo.systemUptime)
    }

    private func readKeyCount() {
        let count = Self.keyDownCount()
        guard count != keyCount else { return }
        keyCount = count
        handle(hold.keyPressed(), at: 0)
    }

    /// Keys pressed on the keyboard, without those a program sends.
    private static func keyDownCount() -> UInt32 {
        return CGEventSource.counterForEventType(.hidSystemState, eventType: .keyDown)
    }

    private static func flags(for modifiers: [String]) -> CGEventFlags {
        return modifiers.reduce(into: CGEventFlags()) { flags, modifier in
            switch modifier.lowercased() {
            case "control": flags.insert(.maskControl)
            case "shift": flags.insert(.maskShift)
            case "command": flags.insert(.maskCommand)
            case "option": flags.insert(.maskAlternate)
            default: break
            }
        }
    }
}
