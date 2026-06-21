#!/usr/bin/env bash
#
# scripts/release.sh — cut a new release of Hasami.
#
# Usage: scripts/release.sh <major|minor|patch>
#
# Bumps the single project version in Sources/Hasami/Version.swift, verifies a
# clean release build and passing tests, then commits the bump, tags it
# (vX.Y.Z), and pushes the commit and tag to GitHub. If the build or tests
# fail, the tentative version bump is reverted and no commit/tag is created.
#
# Requires the `semver` CLI (node-semver) to be on PATH.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$REPO_ROOT/Sources/Hasami/Version.swift"
cd "$REPO_ROOT"

err() { printf 'error: %s\n' "$1" >&2; exit 1; }

# --- validate the release-type argument -------------------------------------
# Note: `semver -i <level>` silently defaults to a patch bump on an unknown
# level, so the level must be validated here before it reaches semver.
LEVEL="${1:-}"
case "$LEVEL" in
    major|minor|patch) ;;
    *) err "usage: $(basename "$0") <major|minor|patch>" ;;
esac

# --- preconditions: on main, clean working tree -----------------------------
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "$BRANCH" == "main" ]] || err "must be on 'main' (currently on '$BRANCH')"
[[ -z "$(git status --porcelain)" ]] || err "working tree is not clean; commit or stash changes first"

# --- read the current version -----------------------------------------------
OLD_VERSION="$(grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' "$VERSION_FILE" | tr -d '"' | head -1)"
[[ -n "$OLD_VERSION" ]] || err "could not read the current version from $VERSION_FILE"

# --- compute the new version ------------------------------------------------
NEW_VERSION="$(semver -i "$LEVEL" "$OLD_VERSION")"
[[ -n "$NEW_VERSION" ]] || err "semver failed to compute the new version"
TAG="v$NEW_VERSION"

# Guard against an existing tag before doing any expensive work.
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    err "tag $TAG already exists"
fi

printf 'Releasing %s -> %s (%s)\n' "$OLD_VERSION" "$NEW_VERSION" "$LEVEL"

# --- tentatively bump the version file --------------------------------------
sed -i '' -E "s/(hasamiVersion = )\"[0-9]+\.[0-9]+\.[0-9]+\"/\1\"$NEW_VERSION\"/" "$VERSION_FILE"

# Revert the tentative bump. The clean-tree precondition guarantees the version
# file's only change is this bump, so checking it out restores the old version.
revert() { git checkout -- "$VERSION_FILE"; }

# swift-testing needs a full Xcode toolchain; the macOS CommandLineTools lack the
# Testing module. If the active developer dir is CommandLineTools and the caller
# hasn't set DEVELOPER_DIR, fall back to the newest installed Xcode (preferring a
# non-beta one). Set DEVELOPER_DIR yourself to override this.
if [[ -z "${DEVELOPER_DIR:-}" ]] && xcode-select -p 2>/dev/null | grep -q CommandLineTools; then
    xcode="$(ls -d /Applications/Xcode*.app 2>/dev/null | grep -vi beta | sort -V | tail -1)"
    [[ -z "$xcode" ]] && xcode="$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -V | tail -1)"
    [[ -n "$xcode" ]] && export DEVELOPER_DIR="$xcode/Contents/Developer"
fi

# --- verify: release build + full test suite --------------------------------
echo "==> swift build -c release"
if ! swift build -c release; then
    revert
    err "release build failed; version reverted to $OLD_VERSION"
fi

echo "==> swift test"
if ! swift test; then
    revert
    err "tests failed; version reverted to $OLD_VERSION"
fi

# --- commit, tag, and push --------------------------------------------------
git add "$VERSION_FILE"
git commit -m "Release $TAG"
git tag -a "$TAG" -m "Release $TAG"
git push origin main
git push origin "$TAG"

printf 'Released %s\n' "$TAG"
