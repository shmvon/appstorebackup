#!/bin/bash
set -e

echo "=== Building AppStoreBackup.app ==="

# Define directories
WORKSPACE_DIR="/Users/semvandekerckhove/Google Drive - sem/_Code/AntiGravity/260522_AppStoreBackup"
APP_BUNDLE="$WORKSPACE_DIR/AppStoreBackup.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous build and temp assets (flushing build cache)
echo "Flushing build cache and old assets..."
rm -rf "$APP_BUNDLE"
rm -f "$WORKSPACE_DIR/AppIcon.icns"
rm -rf "$WORKSPACE_DIR/AppIcon.iconset"

# Create directory structure
echo "Creating bundle directories..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Get macOS SDK path
SDK_PATH=$(xcrun --show-sdk-path)
echo "Using SDK: $SDK_PATH"

# Generate App Icon
echo "Generating AppIcon.icns using GenerateAppIcon.swift..."
swift -sdk "$SDK_PATH" "$WORKSPACE_DIR/src/GenerateAppIcon.swift"

# Copy App Icon into bundle resources
if [ -f "$WORKSPACE_DIR/AppIcon.icns" ]; then
    echo "Copying AppIcon.icns to Resources..."
    cp "$WORKSPACE_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    rm -f "$WORKSPACE_DIR/AppIcon.icns"
else
    echo "Error: AppIcon.icns was not generated successfully."
    exit 1
fi

# Compile Swift files
echo "Compiling Swift source files..."
swiftc -sdk "$SDK_PATH" \
       "$WORKSPACE_DIR/src/BackupManager.swift" \
       "$WORKSPACE_DIR/src/main.swift" \
       -o "$MACOS_DIR/AppStoreBackup"

# Copy Info.plist
echo "Copying Info.plist..."
cp "$WORKSPACE_DIR/src/Info.plist" "$CONTENTS_DIR/Info.plist"

# Verify compiled binary permissions
chmod +x "$MACOS_DIR/AppStoreBackup"

# Force register with LaunchServices to refresh Finder info & icon cache
echo "Registering application with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_BUNDLE"

echo "=== Build Completed Successfully ==="
echo "You can find the app bundle at: $APP_BUNDLE"
echo "To run it, double-click the app in Finder or run in terminal:"
echo "open '$APP_BUNDLE'"
