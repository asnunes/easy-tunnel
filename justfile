dev: build
    open "target/release/bundle/macos/Easy Tunnel.app"

build:
    native/build.sh

test:
    cargo test --lib
    native/test.sh

layers:
    python3 scripts/check_layers.py

check: layers test
    cargo fmt --check
    cargo clippy --lib -- -D warnings
    native/build.sh
