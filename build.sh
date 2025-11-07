#!/bin/bash

# Build script for Hotkey Commander

set -e

echo "Building Hotkey Commander..."

# Clean previous build
rm -rf build/

# Build the project
xcodebuild \
    -project HotkeyCommander.xcodeproj \
    -scheme HotkeyCommander \
    -configuration Release \
    -derivedDataPath build \
    clean build

echo ""
echo "✅ Build completed successfully!"
echo ""
echo "Application location:"
echo "  build/Build/Products/Release/HotkeyCommander.app"
echo ""
echo "To install:"
echo "  cp -r build/Build/Products/Release/HotkeyCommander.app /Applications/"
echo ""
