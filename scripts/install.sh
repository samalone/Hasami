#!/usr/bin/env bash
#
# scripts/install.sh — build, test, and install the Hasami command-line tools.
#
# Does a release build and runs the full test suite; only if the tests pass does
# it install the `sukashi` and `sukashi-plan` executables into /usr/local/bin
# (overridable with PREFIX). Installation uses sudo only when the destination
# isn't writable (e.g. the root-owned /usr/local on Apple Silicon).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PREFIX="${PREFIX:-/usr/local}"
DEST_BIN="$PREFIX/bin"
EXECUTABLES=(sukashi sukashi-plan)

# swift-testing needs a full Xcode toolchain; the macOS CommandLineTools lack the
# Testing module's search-path configuration. If the active developer dir is the
# CommandLineTools and the caller hasn't set DEVELOPER_DIR, fall back to the
# newest installed Xcode (preferring a non-beta). Set DEVELOPER_DIR to override.
if [[ -z "${DEVELOPER_DIR:-}" ]] && xcode-select -p 2>/dev/null | grep -q CommandLineTools; then
    xcode="$(ls -d /Applications/Xcode*.app 2>/dev/null | grep -vi beta | sort -V | tail -1)"
    [[ -z "$xcode" ]] && xcode="$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -V | tail -1)"
    [[ -n "$xcode" ]] && export DEVELOPER_DIR="$xcode/Contents/Developer"
fi

echo "==> swift build -c release"
swift build -c release

# `set -e` aborts here if any test fails, so the install below only runs on green.
echo "==> swift test"
swift test

BIN_PATH="$(swift build -c release --show-bin-path)"

SUDO=""
[[ -w "$DEST_BIN" ]] || SUDO="sudo"
echo "==> installing to $DEST_BIN${SUDO:+ (via sudo)}"
$SUDO mkdir -p "$DEST_BIN"
for exe in "${EXECUTABLES[@]}"; do
    $SUDO install -m 0755 "$BIN_PATH/$exe" "$DEST_BIN/$exe"
    echo "    installed $DEST_BIN/$exe"
done

echo "Installed ${EXECUTABLES[*]} -> $DEST_BIN"
