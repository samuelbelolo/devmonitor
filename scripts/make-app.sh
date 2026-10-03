#!/bin/bash
# Builds DevMonitor.app in build/ and signs it locally (ad hoc), for personal use on this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product DevMonitorApp
app="build/DevMonitor.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp ".build/release/DevMonitorApp" "$app/Contents/MacOS/DevMonitor"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>DevMonitor</string>
    <key>CFBundleIdentifier</key><string>local.devmonitor</string>
    <key>CFBundleName</key><string>DevMonitor</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$app"
echo "$app"
