default: run

alias r := run

setup_cmd := if os_family() == "windows" { "powershell -ExecutionPolicy Bypass -File scripts/setup.ps1" } else { "bash scripts/setup.sh" }

run:
    cargo run --release

setup:
    {{setup_cmd}}
