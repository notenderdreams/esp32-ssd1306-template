#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

FLASH_AFTER_SETUP="${1:-}"

info() {
	echo "[setup] $*"
}

warn() {
	echo "[setup][warn] $*" >&2
}

has_cmd() {
	command -v "$1" >/dev/null 2>&1
}

install_cargo_bin_if_missing() {
	local bin="$1"
	if has_cmd "$bin"; then
		info "$bin already installed"
	else
		info "installing $bin"
		cargo install --locked "$bin"
	fi
}

ensure_rust_src_component() {
	local active_toolchain
	active_toolchain="$(rustup show active-toolchain | awk '{print $1}')"

	if [[ -z "$active_toolchain" ]]; then
		warn "could not determine active toolchain; skipping rust-src install"
		return 0
	fi

	if [[ "$active_toolchain" == "esp" ]]; then
		warn "active toolchain is 'esp' (linked/custom); skipping rust-src install"
		return 0
	fi

	info "ensuring rust-src is installed for toolchain '$active_toolchain'"
	if ! rustup component add rust-src --toolchain "$active_toolchain"; then
		warn "failed to add rust-src for '$active_toolchain'; continuing"
	fi
}

append_line_if_missing() {
	local line="$1"
	local file="$2"

	touch "$file"
	if ! grep -Fqx "$line" "$file"; then
		echo "$line" >> "$file"
		info "added environment line to $file"
	fi
}

info "project root: $PROJECT_ROOT"

# 1. Install espup and Xtensa toolchain support.
install_cargo_bin_if_missing espup
info "running espup install"
espup install

# 2. Load esp environment if available.
if [[ -f "$HOME/export-esp.sh" ]]; then
	# shellcheck source=/dev/null
	. "$HOME/export-esp.sh"
	append_line_if_missing '. "$HOME/export-esp.sh"' "$HOME/.bashrc"
	info "loaded $HOME/export-esp.sh"
elif [[ -f "$HOME/export-esp.ps1" ]]; then
	warn "found export-esp.ps1. For native Windows PowerShell use scripts/setup.ps1"
else
	warn "esp environment export script not found yet. Open a new shell if rustup override fails."
fi

# 3. Install flash tool.
install_cargo_bin_if_missing espflash

# 4. Configure project toolchain.
info "setting rustup override to esp"
rustup override set esp

# 5. Install rust-src for this toolchain.
ensure_rust_src_component

# 6. Build.
info "updating lockfile"
cargo update
info "building project"
cargo build

# 7. Optional flash + monitor.
if [[ "$FLASH_AFTER_SETUP" == "--flash" ]]; then
	info "flashing and opening monitor"
	cargo run
	espflash monitor
else
	info "setup finished"
	info "next steps: cargo run --release"
	info "or run: bash scripts/setup.sh --flash"
fi