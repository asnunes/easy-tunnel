#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

app_path="target/release/bundle/macos/Easy Tunnel.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
# Bash 3 on macOS has no mapfile; source paths have no spaces.
swift_sources=()
while IFS= read -r source; do swift_sources+=("$source"); done < <(find native/Sources -name '*.swift' -print | sort)
xcrun swiftc -swift-version 5 -O -target "$(uname -m)-apple-macosx13.0" \
    "${swift_sources[@]}" \
    -framework AppKit -framework SwiftUI \
    -o "$app_path/Contents/MacOS/easy-tunnel"
cp native/Info.plist "$app_path/Contents/Info.plist"
cp icons/icon.icns "$app_path/Contents/Resources/icon.icns"
cp icons/tray.png "$app_path/Contents/Resources/tray.png"
codesign --force --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
echo "Built $app_path"
