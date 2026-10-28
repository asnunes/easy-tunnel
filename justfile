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
