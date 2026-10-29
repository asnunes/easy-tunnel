dev:
    npm --prefix web run desktop -- dev

build:
    npm --prefix web run desktop -- build

test:
    cargo test --lib
    npm --prefix web test

layers:
    python3 scripts/check_layers.py

check: layers test
    cargo fmt --check
    cargo clippy --lib -- -D warnings
    npm --prefix web run build

icons:
    web/node_modules/.bin/tauri icon icons/icon.svg --output target/icon-generation/app
    web/node_modules/.bin/tauri icon icons/tray.svg --output target/icon-generation/tray --png 44
    cp target/icon-generation/app/icon.png icons/icon.png
    cp target/icon-generation/app/icon.icns icons/icon.icns
    cp target/icon-generation/tray/44x44.png icons/tray.png
