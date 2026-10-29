#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
cargo build --lib
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macosx13.0" \
    -import-objc-header native/Bridge/easy_tunnel.h \
    native/Sources/Presentation/Models.swift native/Sources/Presentation/ConnectionDraft.swift \
    native/Sources/Presentation/BackendClient.swift native/Sources/Presentation/ConnectionStore.swift \
    native/Tests/TestBackend.swift native/Tests/NativeTests.swift target/debug/libeasy_tunnel.a \
    -framework Security -framework SystemConfiguration -o target/native-tests
./target/native-tests
