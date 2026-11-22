# Hotkey Commander

A lightweight macOS menu bar application that executes shell commands using customizable keyboard shortcuts.

## Features

- **Background Operation**: Runs silently in the menu bar
- **Auto-Start**: Automatically launches at login (can be configured)
- **Menu Bar Icon**: Quick access via system menu bar
- **Customizable Hotkeys**: Configure your own activation key combination (default: Control + Shift)
- **Button Panel**: Hold the activation hotkey to see your commands as buttons on screen
- **Phone**: Run the same buttons from a phone on your Wi-Fi
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
4. Grant accessibility permissions when prompted (required for the button panel)

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
2. Select **Configure…**
3. In the **Buttons** tab:
   - **Change Activation Hotkey**: Click "Change", press your desired modifier combination, then click "OK"
   - **Add Buttons**: Click "+", then enter a command and at least a key, a name or an icon
   - **Edit Buttons**: Click a button in the grid
   - **Set Icons**: Drop an image (PNG, JPG, SVG, ICNS) or an app on a button, or click the preview to choose one
   - **Reorder Buttons**: Drag a button to its new place
   - **Delete Buttons**: Click a button, then "Delete button"
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

### Button Panel

Hold the activation hotkey to show your buttons over whatever is on screen, full-screen apps included. The app you are working in keeps the keyboard focus.

- Click a button to run it. The panel stays open until you release the hotkey
- Press a button's key to run it. The panel closes at once
- Uncheck **Show Panel** in the menu to use only the keys

Commands run to their end, even after you release the keys or quit the app. Running a button again starts another run.

### Phone

A phone on the same Wi-Fi can show the same buttons in its browser:

1. In the **Phone** tab of **Configure…**, turn on **Allow phones**
2. Click **Add device…**, enter a name and click "OK"
3. Scan the code with the phone's camera

The link keeps working after a restart and on any network both devices share, until you click **Remove** or rename the Mac. The app listens on port 47110, on the local network only. The connection is not encrypted, so use it only on Wi-Fi you trust.

## Configuration Storage

All settings, including the saved phones, are stored in `UserDefaults` under the key `HotkeyCommanderConfiguration`. Icons are stored in `~/Library/Application Support/com.hotkeycommander.app/icons`. To reset the app:

```bash
defaults delete com.hotkeycommander.app
rm -r ~/Library/Application\ Support/com.hotkeycommander.app
```

## Project Structure

```
HotkeyCommander/
├── Sources/
│   ├── AppDelegate.swift                    # Main application entry point
│   ├── ConfigurationManager.swift           # Handles configuration storage
│   ├── HotkeyManager.swift                  # Activation hotkey plus a button's key
│   ├── ActivationMonitor.swift              # Notices the activation hotkey being held
│   ├── ScriptRunner.swift                   # Runs a button's command and logs failures
│   ├── LoginShellPath.swift                 # PATH the commands run with
│   ├── IconStore.swift                      # The app's copies of the icons
│   ├── AppPaths.swift                       # Where the app keeps its files
│   ├── DeckPanelController.swift            # Button panel
│   ├── ButtonFace.swift                     # How a button looks
│   ├── ConfigurationWindowController.swift  # Settings window UI
│   ├── SettingsDraft.swift                  # Edits before Save
│   ├── ButtonGridView.swift                 # Button grid and preview in Settings
│   ├── FieldBox.swift                       # Text fields in Settings
│   ├── ChangeHotkeySheet.swift              # Dialog for a new activation hotkey
│   ├── ModifierNames.swift                  # Activation hotkey as text
│   ├── PhoneController.swift                # Phones, as the rest of the app sees them
│   ├── PhoneServer.swift                    # Answers phones on the local network
│   ├── PhoneConnection.swift                # One request from a phone
│   ├── PhonePage.swift                      # The page a phone opens
│   ├── PhoneSettingsView.swift              # Phone tab of Settings
│   ├── AddDeviceSheet.swift                 # Dialog with the code to scan
│   └── LaunchAtLoginManager.swift          # Auto-start functionality
├── Resources/
└── Supporting Files/
    ├── Info.plist                          # App metadata
    └── HotkeyCommander.entitlements        # Required permissions
```

## Troubleshooting

### Hotkeys not working

1. Make sure no other app is using the same hotkey combination
2. Try changing the activation hotkey in settings

### Panel not showing

1. Check that accessibility permissions are granted. The hotkeys work without them, the panel does not
2. Check that **Show Panel** is checked in the menu

### App doesn't start at login

The app should automatically register for launch at login. If it doesn't:

1. Go to **System Preferences → Users & Groups → Login Items**
2. Add Hotkey Commander manually if needed

### Commands not executing

1. Verify the command works in Terminal first
2. Check `~/Library/Logs/HotkeyCommander/deck.log`, where failed commands are listed with their output
3. Check that the command is found in a new Terminal window. Commands run with that PATH, read when the app starts
4. Some commands may require additional permissions

## Development

### Code Style

- Swift 5.0+
- Uses AppKit for UI
- Follows Apple's Human Interface Guidelines
- Minimal dependencies (no external frameworks)

### Key Components

- **AppDelegate**: Main coordinator, sets up status bar and manages app lifecycle
- **HotkeyManager**: Listens for the activation hotkey plus a button's key
- **ActivationMonitor**: Notices when the activation hotkey is held and let go
- **DeckPanelController**: Shows the button panel
- **ScriptRunner**: Runs a button's command by its id, for the hotkeys, the panel and the phones
- **PhoneServer**: Serves the phones' page and passes on their touches
- **ConfigurationManager**: Persists user settings
- **ConfigurationWindowController**: Provides UI for managing buttons and phones

## License

This is a personal project. Feel free to modify and use as needed.

## Credits

Created as a simple utility for executing macOS commands via keyboard shortcuts.
