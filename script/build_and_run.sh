#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/Lume.xcodeproj"
SCHEME="IPTVX"
CONFIGURATION="Sideload"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/$CONFIGURATION/Lume.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Lume"

resolve_developer_dir() {
    if [[ -n "${DEVELOPER_DIR:-}" && -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
        printf '%s\n' "$DEVELOPER_DIR"
        return
    fi

    local selected
    selected="$(xcode-select -p 2>/dev/null || true)"
    if [[ -x "$selected/usr/bin/xcodebuild" ]]; then
        printf '%s\n' "$selected"
        return
    fi

    local candidate
    for candidate in \
        "/Applications/Xcode-beta.app/Contents/Developer" \
        "/Applications/Xcode.app/Contents/Developer" \
        "$HOME/Applications/Xcode-beta.app/Contents/Developer" \
        "$HOME/Applications/Xcode.app/Contents/Developer"; do
        if [[ -x "$candidate/usr/bin/xcodebuild" ]]; then
            printf '%s\n' "$candidate"
            return
        fi
    done

    echo "IPTVX needs Xcode 26 beta or newer to build Apple targets." >&2
    echo "Install Xcode, then run: sudo xcode-select --switch /Applications/Xcode-beta.app/Contents/Developer" >&2
    exit 78
}

DEVELOPER_DIR="$(resolve_developer_dir)"
export DEVELOPER_DIR

pkill -x Lume >/dev/null 2>&1 || true

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build

if [[ ! -x "$APP_BINARY" ]]; then
    echo "Build completed without the expected app: $APP_BUNDLE" >&2
    exit 1
fi

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
    run)
        open_app
        ;;
    --debug|debug)
        lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate 'process == "Lume"'
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate 'process == "Lume"'
        ;;
    --verify|verify)
        open_app
        sleep 1
        pgrep -x Lume >/dev/null
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
