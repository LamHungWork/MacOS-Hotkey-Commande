# Hotkey Commander

A lightweight macOS menu bar application that executes shell commands using customizable keyboard shortcuts.

## Features

- **Background Operation**: Runs silently in the menu bar
- **Auto-Start**: Automatically launches at login (can be configured)
- **Menu Bar Icon**: Quick access via system menu bar
- **Customizable Hotkeys**: Configure your own activation key combination (default: Control + Shift)
- **Toggle Mode**: Commands start when you press the hotkey and stop when you release it
- **Simple Configuration**: Easy-to-use settings window for managing shortcuts

## Requirements

- macOS 12.0 or later
- Xcode 15.0 or later (for building)

## Building the Application

### Using Xcode

1. Open `HotkeyCommander.xcodeproj` in Xcode
2. Select the "HotkeyCommander" scheme
3. Build the project: `Product → Build` (⌘B)
4. Run: `Product → Run` (⌘R)

### Using Command Line

```bash
# Build the project
xcodebuild -project HotkeyCommander.xcodeproj -scheme HotkeyCommander -configuration Release build

# The built application will be in:
# build/Release/HotkeyCommander.app
```

## Installation

1. Build the application using one of the methods above
2. Copy `HotkeyCommander.app` to your `/Applications` folder
3. Launch the application
4. Grant accessibility permissions when prompted (required for global keyboard shortcuts)

### Granting Accessibility Permissions

On first launch, macOS will prompt you to grant accessibility permissions:

1. Go to **System Preferences → Security & Privacy → Accessibility**
2. Click the lock icon to make changes
3. Add **Hotkey Commander** to the list and check the box
4. Restart the application if necessary

## Usage

### Basic Usage

1. The app runs in the menu bar (look for the ⌨︎ icon)
2. Click the icon to see your configured shortcuts
3. Click **Configure...** to set up new shortcuts
4. Press your activation hotkey (default: Control + Shift) + a configured key to execute a command

### Configuring Shortcuts

1. Click the menu bar icon (⌨︎)
2. Select **Configure...**
3. In the configuration window:
   - **Change Activation Hotkey**: Click "Change" and press your desired modifier combination
   - **Add Shortcuts**: Enter a single key and the command to execute, then click "+ Add New"
   - **Delete Shortcuts**: Click the × button next to any shortcut
4. Click **Save** to apply changes

### Example Shortcuts

Here are some useful shortcuts to get started:

| Key | Command | Description |
|-----|---------|-------------|
| S | `open -a "Google Chrome"` | Open Chrome |
| C | `open -a "Calculator"` | Open Calculator |
| T | `open -a "Terminal"` | Open Terminal |
| F | `open -a "Finder"` | Open Finder |
| V | `open -a "Visual Studio Code"` | Open VS Code |

### Toggle Mode

Commands start when you press the hotkey combination and stop when you release it. This is useful for:

- Running continuous processes
- Opening apps (they stay open after you release the key)
- Executing scripts that run in the background

## Configuration Storage

All settings are stored in `UserDefaults` under the key `HotkeyCommanderConfiguration`. To reset the app:

```bash
defaults delete com.hotkeycommander.app
```

## Project Structure

```
HotkeyCommander/
├── Sources/
│   ├── AppDelegate.swift                    # Main application entry point
│   ├── ConfigurationManager.swift           # Handles configuration storage
│   ├── HotkeyManager.swift                  # Global hotkey listening and command execution
│   ├── ConfigurationWindowController.swift  # Settings window UI
│   └── LaunchAtLoginManager.swift          # Auto-start functionality
├── Resources/
└── Supporting Files/
    ├── Info.plist                          # App metadata
    └── HotkeyCommander.entitlements        # Required permissions
```

## Troubleshooting

### Hotkeys not working

1. Check that accessibility permissions are granted
2. Make sure no other app is using the same hotkey combination
3. Try changing the activation hotkey in settings

### App doesn't start at login

The app should automatically register for launch at login. If it doesn't:

1. Go to **System Preferences → Users & Groups → Login Items**
2. Add Hotkey Commander manually if needed

### Commands not executing

1. Verify the command works in Terminal first
2. Check that the command path is correct (use full paths if needed)
3. Some commands may require additional permissions

## Development

### Code Style

- Swift 5.0+
- Uses AppKit for UI
- Follows Apple's Human Interface Guidelines
- Minimal dependencies (no external frameworks)

### Key Components

- **AppDelegate**: Main coordinator, sets up status bar and manages app lifecycle
- **HotkeyManager**: Monitors global keyboard events and executes commands
- **ConfigurationManager**: Persists and validates user settings
- **ConfigurationWindowController**: Provides UI for managing shortcuts

## License

This is a personal project. Feel free to modify and use as needed.

## Credits

Created as a simple utility for executing macOS commands via keyboard shortcuts.
