#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

cargo build --release --lib
app_path="target/release/bundle/macos/Easy Tunnel.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
# Bash 3 on macOS has no mapfile; source paths have no spaces.
swift_sources=()
while IFS= read -r source; do swift_sources+=("$source"); done < <(find native/Sources -name '*.swift' -print | sort)
xcrun swiftc -swift-version 5 -O -target "$(uname -m)-apple-macosx13.0" \
    -import-objc-header native/Bridge/easy_tunnel.h \
    "${swift_sources[@]}" target/release/libeasy_tunnel.a \
    -framework AppKit -framework SwiftUI -framework Security -framework SystemConfiguration \
    -o "$app_path/Contents/MacOS/easy-tunnel"
cp native/Info.plist "$app_path/Contents/Info.plist"
python3 - "$app_path/Contents/Info.plist" <<'PY'
import json, plistlib, subprocess, sys
metadata = json.loads(subprocess.check_output(['cargo', 'metadata', '--no-deps', '--format-version', '1']))
version = next(p['version'] for p in metadata['packages'] if p['name'] == 'easy-tunnel')
with open(sys.argv[1], 'rb') as file:
    info = plistlib.load(file)
info['CFBundleShortVersionString'] = version
info['CFBundleVersion'] = version
with open(sys.argv[1], 'wb') as file:
    plistlib.dump(info, file)
PY
cp icons/icon.icns "$app_path/Contents/Resources/icon.icns"
cp icons/tray.png "$app_path/Contents/Resources/tray.png"
codesign --force --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
echo "Built $app_path"
