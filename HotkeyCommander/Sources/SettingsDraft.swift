import Cocoa

/// The edits made in Settings, kept apart from the configuration until Save.
final class SettingsDraft {
    struct Button {
        enum Icon {
            case none
            case saved(name: String, image: NSImage)
            case new(png: Data, image: NSImage)

            var image: NSImage? {
                switch self {
                case .none: return nil
                case .saved(_, let image), .new(_, let image): return image
                }
            }
        }

        let id: String
        var name = ""
        var key = ""
        var command = ""
        var icon = Icon.none

        var face: ButtonFace {
            return ButtonFace(name: name, key: key, icon: icon.image)
        }

        var displayName: String {
            return shortcut(icon: nil).displayName
        }

        func shortcut(icon: String?) -> ShortcutConfig {
            return ShortcutConfig(id: id, key: key, command: command, name: face.name.isEmpty ? nil : face.name, icon: icon)
        }
    }

    struct Problems {
        var key: String?
        var command: String?
        var face: String?

        var isEmpty: Bool {
            return key == nil && command == nil && face == nil
        }
    }

    var modifiers: [String]
    private(set) var buttons: [Button]

    init(configuration: AppConfiguration, iconStore: IconStore) {
        modifiers = configuration.activationModifiers
        buttons = configuration.shortcuts.map { shortcut in
            let icon = shortcut.icon.flatMap { name in
                iconStore.image(named: name).map { Button.Icon.saved(name: name, image: $0) }
            }
            return Button(
                id: shortcut.id, name: shortcut.name ?? "", key: shortcut.key, command: shortcut.command, icon: icon ?? .none
            )
        }
    }

    // MARK: - Editing

    func button(id: String?) -> Button? {
        return buttons.first { $0.id == id }
    }

    func update(id: String, _ change: (inout Button) -> Void) {
        guard let index = buttons.firstIndex(where: { $0.id == id }) else { return }
        change(&buttons[index])
    }

    /// Returns the new button's id.
    func add(icon: Button.Icon = .none) -> String {
        let button = Button(id: UUID().uuidString, icon: icon)
        buttons.append(button)
        return button.id
    }

    func remove(id: String) {
        buttons.removeAll { $0.id == id }
    }

    /// The button takes the place of the one at `index`.
    func move(id: String, to index: Int) {
        guard let from = buttons.firstIndex(where: { $0.id == id }), buttons.indices.contains(index) else { return }
        buttons.insert(buttons.remove(at: from), at: index)
    }

    // MARK: - Validity

    func problems(of button: Button) -> Problems {
        var problems = Problems()
        if !button.key.isEmpty, HotkeyManager.keyCode(for: button.key) == nil {
            problems.key = "This key can't be used as a hotkey."
        } else if !button.key.isEmpty,
           let other = buttons.first(where: { $0.id != button.id && $0.key.lowercased() == button.key.lowercased() }) {
            problems.key = "Key \(button.key.uppercased()) is already used by \(other.displayName)."
        }
        if button.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.command = "Command is required."
        }
        if button.key.isEmpty, button.face.name.isEmpty, button.icon.image == nil {
            problems.face = "Set a key, a name or an icon."
        }
        return problems
    }

    var isValid: Bool {
        return !modifiers.isEmpty && buttons.allSatisfy { problems(of: $0).isEmpty }
    }

    // MARK: - Saving

    /// Writes the new icons first. When one cannot be written, nothing is saved.
    func save(to configManager: ConfigurationManager, iconStore: IconStore) throws {
        var written: [String] = []
        var shortcuts: [ShortcutConfig] = []
        do {
            for button in buttons {
                var icon: String?
                switch button.icon {
                case .none:
                    break
                case .saved(let name, _):
                    icon = name
                case .new(let png, _):
                    let name = try iconStore.save(png)
                    written.append(name)
                    icon = name
                }
                shortcuts.append(button.shortcut(icon: icon))
            }
        } catch {
            written.forEach(iconStore.remove(named:))
            throw error
        }

        let before = Set(configManager.getShortcuts().compactMap(\.icon))
        configManager.updateConfiguration(activationModifiers: modifiers, shortcuts: shortcuts)
        before.subtracting(shortcuts.compactMap(\.icon)).forEach(iconStore.remove(named:))
    }
}
