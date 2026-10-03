#!/bin/bash
# Installs DevMonitor: builds it from source on this Mac, copies it to the Applications folder and launches it.
# Usage: curl -fsSL https://raw.githubusercontent.com/samuelbelolo/devmonitor/main/scripts/install.sh | bash
set -euo pipefail

REPO="https://github.com/samuelbelolo/devmonitor.git"
temporary_dir=""

# Removes the downloaded source, if any, when the script ends.
cleanup() {
  if [ -n "$temporary_dir" ]; then rm -rf "$temporary_dir"; fi
}

# Everything runs from main, called on the last line, so a download cut short runs nothing at all.
main() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "Run this without sudo: DevMonitor is built and installed for your own account." >&2
    exit 1
  fi
  if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]; then
    echo "DevMonitor needs macOS 14 or later." >&2
    exit 1
  fi
  if ! xcrun --find swift >/dev/null 2>&1; then
    echo "DevMonitor is built on your Mac and needs Apple's developer tools." >&2
    echo "Install them with:  xcode-select --install   then run this command again." >&2
    exit 1
  fi

  # /Applications when this account may write there, the account's own Applications folder otherwise.
  local destination="/Applications"
  if [ ! -w "$destination" ]; then
    destination="$HOME/Applications"
    mkdir -p "$destination"
  fi
  local app="$destination/DevMonitor.app"

  # Run from its file inside a checkout (make install), it builds that checkout. Piped from curl, it always
  # downloads the source, whatever the current folder holds.
  local script="${BASH_SOURCE[0]:-}"
  local source_dir
  if [ -n "$script" ] && [ -f "$script" ] && grep -q 'name: "DevMonitor"' "$(dirname "$script")/../Package.swift" 2>/dev/null; then
    source_dir="$(cd "$(dirname "$script")/.." && pwd)"
  else
    temporary_dir="$(mktemp -d)"
    trap cleanup EXIT
    source_dir="$temporary_dir/devmonitor"
    echo "Downloading DevMonitor…"
    git clone --quiet --depth 1 "$REPO" "$source_dir"
  fi

  echo "Building (about a minute the first time)…"
  "$source_dir/scripts/make-app.sh"

  # Copy next to the installed app, check the copy, then swap: a failed copy leaves the current app untouched.
  rm -rf "$app.new"
  cp -R "$source_dir/build/DevMonitor.app" "$app.new"
  codesign --verify "$app.new"
  pkill -u "$(id -u)" -x DevMonitor 2>/dev/null || true
  rm -rf "$app"
  mv "$app.new" "$app"
  open "$app"
  echo "DevMonitor is installed in $destination and running: look for the memory figure in your menu bar."
}

main "$@"
