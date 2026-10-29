#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p target
sources=()
while IFS= read -r source; do sources+=("$source"); done < <(find native/Sources native/Tests -name '*.swift' ! -name 'EasyTunnelApp.swift' ! -name 'Preview.swift' -print | sort)
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macosx13.0" \
    "${sources[@]}" -framework AppKit -framework SwiftUI -o target/native-tests
./target/native-tests
