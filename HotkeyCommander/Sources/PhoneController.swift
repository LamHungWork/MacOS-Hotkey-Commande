import Cocoa
import SystemConfiguration

/// A phone that was given a link. The key in the link is what lets it in.
struct PhoneDevice: Codable {
    let id: String
    let name: String
    let key: String
    let added: Date
}

/// Phones, as Settings and the rest of the app see them. Every change works at once and is saved at once.
final class PhoneController {
    var onChange: (() -> Void)?

    private let configManager: ConfigurationManager
    private let iconStore: IconStore
    private let server = PhoneServer()
    private let appIcon: Data
    private var state = PhoneServer.State.off
    private var isWanted = false
    private var activity: NSObjectProtocol?

    init(configManager: ConfigurationManager, iconStore: IconStore, scriptRunner: ScriptRunner) {
        self.configManager = configManager
        self.iconStore = iconStore
        appIcon = Self.makeAppIcon()
        server.onRun = { id in
            scriptRunner.run(id: id)
        }
        server.onStateChange = { [weak self] state in
            self?.stateChanged(to: state)
        }
    }

    /// Called at launch.
    func start() {
        reload()
        if configManager.arePhonesAllowed {
            isWanted = true
            server.start()
        }
    }

    /// The saved buttons or devices changed.
    func reload() {
        let shortcuts = configManager.getShortcuts()
        // An icon whose file is gone is left out, so the phone shows the name or the key, as the Mac does.
        let icons = shortcuts.map { shortcut in
            shortcut.icon.flatMap { iconStore.image(named: $0) == nil ? nil : $0 } ?? ""
        }
        var content = PhoneContent()
        content.deviceKeys = Set(configManager.phones.map(\.key))
        content.buttonIDs = Set(shortcuts.map(\.id))
        content.icons = Set(icons).subtracting([""])
        content.version = UUID().uuidString
        content.appIcon = appIcon

        let buttons = zip(shortcuts, icons).map { shortcut, icon in
            [
                "id": shortcut.id,
                "name": (shortcut.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                "key": shortcut.key.uppercased(),
                "icon": icon
            ]
        }
        content.buttons = Self.json(buttons) ?? "[]"
        content.macName = Self.json([SCDynamicStoreCopyComputerName(nil, nil) as String? ?? "Mac"]) ?? "[\"Mac\"]"
        server.update(content)
    }

    private static func json<Value: Encodable>(_ value: Value) -> String? {
        return (try? JSONEncoder().encode(value)).map { String(decoding: $0, as: UTF8.self) }
    }

    // MARK: - Allow phones

    /// Whether the switch is shown on.
    var isAllowed: Bool {
        switch state {
        case .starting, .on: return true
        case .off, .failed: return false
        }
    }

    var errorMessage: String? {
        if case .failed(let message) = state {
            return message
        }
        return nil
    }

    func setAllowed(_ allowed: Bool) {
        isWanted = allowed
        if allowed {
            state = .starting
            server.start()
        } else {
            configManager.setPhonesAllowed(false)
            state = .off
            server.stop()
            endActivity()
        }
        onChange?()
    }

    private func stateChanged(to state: PhoneServer.State) {
        // Turned off meanwhile: whatever the server was still about to say no longer counts.
        guard isWanted else { return }

        self.state = state
        switch state {
        case .on:
            if !configManager.arePhonesAllowed {
                configManager.setPhonesAllowed(true)
            }
            // Otherwise macOS slows down an app that has nothing on screen. The Mac may still sleep.
            activity = activity ?? ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep, reason: "Answering phones"
            )
        case .failed:
            isWanted = false
            endActivity()
        case .off, .starting:
            break
        }
        onChange?()
    }

    private func endActivity() {
        if let running = activity {
            ProcessInfo.processInfo.endActivity(running)
        }
        activity = nil
    }

    // MARK: - Devices

    var devices: [PhoneDevice] {
        return configManager.phones
    }

    /// Returns the new device's link.
    func addDevice(named name: String) -> String {
        let key = Self.makeKey()
        configManager.addPhone(PhoneDevice(id: UUID().uuidString, name: name, key: key, added: Date()))
        reload()
        onChange?()
        return "http://\(Self.hostName()):\(PhoneServer.port)/d/\(key)/"
    }

    func removeDevice(id: String) {
        configManager.removePhone(id: id)
        reload()
        onChange?()
    }

    private static func makeKey() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<16).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
    }

    /// The name the Mac has on the local network, which stays when its address changes.
    private static func hostName() -> String {
        guard let name = SCDynamicStoreCopyLocalHostName(nil) as String? else {
            return ProcessInfo.processInfo.hostName
        }
        return name + ".local"
    }

    /// On a plain background: a phone shows no transparency in a Home Screen icon.
    private static func makeAppIcon() -> Data {
        let side = 512
        guard let icon = NSApp.applicationIconImage,
              let bitmap = NSBitmapImageRep(
                  bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
              ),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return Data()
        }

        let frame = NSRect(x: 0, y: 0, width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        DeckColor.panel.setFill()
        frame.fill()
        icon.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:]) ?? Data()
    }
}
