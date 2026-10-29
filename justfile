dev: build
    open "target/release/bundle/macos/Easy Tunnel.app"

build:
    native/build.sh

test:
    native/test.sh

layers:
    python3 scripts/check_layers.py

check: layers test
    native/build.sh
