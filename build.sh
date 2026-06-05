#!/bin/bash
set -e

# Suffix selection dialog box
SUFFIX=""
echo "Prompting for suffix selection..."
CHOICE=$(osascript -e '
tell application "System Events"
    activate
    set theResult to display dialog "Select a suffix option for the AppStoreBackup name:" buttons {"No Suffix", "Computer Name", "Custom Name"} default button "No Suffix" with title "Build AppStoreBackup"
    return button returned of theResult
end tell' 2>/dev/null)

# Check if osascript failed (user closed dialog, etc.)
if [ $? -ne 0 ] || [ -z "$CHOICE" ]; then
    echo "Build cancelled by user."
    exit 0
fi

if [ "$CHOICE" = "Computer Name" ]; then
    COMPUTER_NAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || echo "Mac")
    SUFFIX="_$COMPUTER_NAME"
elif [ "$CHOICE" = "Custom Name" ]; then
    CUSTOM_VAL=$(osascript -e '
    tell application "System Events"
        activate
        set theResult to display dialog "Enter custom suffix for the app name:" default answer "" buttons {"Cancel", "OK"} default button "OK" with title "Custom Suffix"
        return text returned of theResult
    end tell' 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Build cancelled by user."
        exit 0
    fi
    # Sanitize custom name: keep only alphanumeric, dashes, and underscores
    CUSTOM_VAL_CLEAN=$(echo "$CUSTOM_VAL" | sed 's/[^a-zA-Z0-9_-]/_/g')
    if [ -z "$CUSTOM_VAL_CLEAN" ]; then
        echo "Error: Custom suffix is empty or invalid."
        exit 1
    fi
    SUFFIX="_$CUSTOM_VAL_CLEAN"
fi

APP_NAME="AppStoreBackup${SUFFIX}"
echo "=== Building ${APP_NAME}.app ==="

# Define directories
WORKSPACE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$WORKSPACE_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DEPLOYMENT_TARGET="14.0"
SWIFT_TARGET="arm64-apple-macos$DEPLOYMENT_TARGET"
MODULE_CACHE_DIR="$WORKSPACE_DIR/.build/module-cache"
ICON_WORK_DIR=$(mktemp -d /private/tmp/AppStoreBackupIcon.XXXXXX)

export MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"

# Clean previous build and temp assets (flushing build cache)
echo "Flushing build cache and old assets..."
rm -rf "$APP_BUNDLE"
rm -f "$WORKSPACE_DIR/AppIcon.icns"
rm -rf "$WORKSPACE_DIR/AppIcon.iconset"
rm -rf "$MODULE_CACHE_DIR"

# Create directory structure
echo "Creating bundle directories..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$MODULE_CACHE_DIR"

# Get macOS SDK path. Prefer the stable macOS 15 SDK when present so
# builds made on newer Macs still run on macOS 14/15 Apple Silicon Macs.
PREFERRED_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [ -d "$PREFERRED_SDK" ]; then
    SDK_PATH="$PREFERRED_SDK"
else
    SDK_PATH=$(xcrun --show-sdk-path)
fi
echo "Using SDK: $SDK_PATH"
echo "Using deployment target: macOS $DEPLOYMENT_TARGET ($SWIFT_TARGET)"

# Generate or copy App Icon
if [ -f "$WORKSPACE_DIR/src/AppIcon.icns" ]; then
    echo "Copying source AppIcon.icns..."
    cp "$WORKSPACE_DIR/src/AppIcon.icns" "$WORKSPACE_DIR/AppIcon.icns"
else
    echo "Generating AppIcon.icns using GenerateAppIcon.swift..."
    (
        cd "$ICON_WORK_DIR"
        swift -sdk "$SDK_PATH" \
              -module-cache-path "$MODULE_CACHE_DIR" \
              "$WORKSPACE_DIR/src/GenerateAppIcon.swift"
    )
    cp "$ICON_WORK_DIR/AppIcon.icns" "$WORKSPACE_DIR/AppIcon.icns"
fi
rm -rf "$ICON_WORK_DIR"

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
       -module-cache-path "$MODULE_CACHE_DIR" \
       -target "$SWIFT_TARGET" \
       "$WORKSPACE_DIR/src/BackupManager.swift" \
       "$WORKSPACE_DIR/src/main.swift" \
       -o "$MACOS_DIR/AppStoreBackup"

# Copy Info.plist
echo "Copying Info.plist..."
cp "$WORKSPACE_DIR/src/Info.plist" "$CONTENTS_DIR/Info.plist"

# Verify compiled binary permissions
chmod +x "$MACOS_DIR/AppStoreBackup"

# Sign ad-hoc so macOS has a complete local code signature for the rebuilt bundle.
echo "Signing application..."
codesign --force --deep --sign - "$APP_BUNDLE"

# Force register with LaunchServices to refresh Finder info & icon cache
echo "Registering application with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_BUNDLE" || \
    echo "Warning: Launch Services registration failed; the app bundle was still built successfully."

echo "=== Build Completed Successfully ==="
echo "You can find the app bundle at: $APP_BUNDLE"
echo "To run it, double-click the app in Finder or run in terminal:"
echo "open '$APP_BUNDLE'"
