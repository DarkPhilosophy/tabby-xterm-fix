#!/usr/bin/env sh
set -eu

PLUGIN_NAME="tabby-xterm-fix"
REPO_URL="${TABBY_XTERM_FIX_REPO_URL:-https://github.com/DarkPhilosophy/tabby-xterm-fix.git}"
BRANCH="${TABBY_XTERM_FIX_BRANCH:-main}"
ARCHIVE_URL="${TABBY_XTERM_FIX_ARCHIVE_URL:-https://github.com/DarkPhilosophy/tabby-xterm-fix/archive/refs/heads/${BRANCH}.tar.gz}"
TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t tabby-xterm-fix)"
BACKUP_DIR=""

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

info() {
    printf '%s\n' "[tabby-xterm-fix] $*"
}

fail() {
    printf '%s\n' "[tabby-xterm-fix] ERROR: $*" >&2
    exit 1
}

is_wsl() {
    [ -n "${WSL_DISTRO_NAME:-}" ] && return 0
    [ -n "${WSL_INTEROP:-}" ] && return 0
    grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null
}

windows_appdata_from_wsl() {
    command -v cmd.exe >/dev/null 2>&1 || return 1
    command -v wslpath >/dev/null 2>&1 || return 1

    win_appdata="$(cmd.exe /C 'echo %APPDATA%' 2>/dev/null | tr -d '\r' | tail -n 1)"
    [ -n "$win_appdata" ] || return 1
    case "$win_appdata" in
        *%APPDATA%*) return 1 ;;
    esac
    wslpath -u "$win_appdata"
}

default_plugins_root() {
    if is_wsl; then
        if appdata_path="$(windows_appdata_from_wsl)"; then
            printf '%s\n' "$appdata_path/tabby/plugins/node_modules"
            return 0
        fi
        fail 'WSL detected, but Windows %APPDATA% could not be resolved. Set TABBY_PLUGINS_ROOT or TABBY_XTERM_FIX_INSTALL_DIR manually.'
    fi

    case "$(uname -s 2>/dev/null || printf unknown)" in
        Darwin)
            [ -n "${HOME:-}" ] || fail 'HOME is not set. Set TABBY_PLUGINS_ROOT or TABBY_XTERM_FIX_INSTALL_DIR manually.'
            printf '%s\n' "$HOME/Library/Application Support/tabby/plugins/node_modules"
            ;;
        *)
            [ -n "${HOME:-}" ] || fail 'HOME is not set. Set TABBY_PLUGINS_ROOT or TABBY_XTERM_FIX_INSTALL_DIR manually.'
            printf '%s\n' "$HOME/.config/tabby/plugins/node_modules"
            ;;
    esac
}

DEFAULT_PLUGINS_ROOT="$(default_plugins_root)"
PLUGINS_ROOT="${TABBY_PLUGINS_ROOT:-$DEFAULT_PLUGINS_ROOT}"
INSTALL_DIR="${TABBY_XTERM_FIX_INSTALL_DIR:-${PLUGINS_ROOT}/${PLUGIN_NAME}}"

fetch_with_git() {
    command -v git >/dev/null 2>&1 || return 1
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_DIR/repo" >/dev/null 2>&1
}

fetch_with_archive() {
    mkdir -p "$TMP_DIR/repo"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$TMP_DIR/repo" --strip-components 1
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$ARCHIVE_URL" | tar -xz -C "$TMP_DIR/repo" --strip-components 1
    else
        return 1
    fi
}

info "Install target: $INSTALL_DIR"
info 'Downloading plugin...'
if ! fetch_with_git; then
    info 'git clone unavailable or failed, trying archive download...'
    fetch_with_archive || fail 'Could not download plugin. Install git, curl, or wget and try again.'
fi

SOURCE_DIR="$TMP_DIR/repo/$PLUGIN_NAME"
[ -f "$SOURCE_DIR/package.json" ] || fail "Plugin package not found at $SOURCE_DIR"
[ -f "$SOURCE_DIR/index.js" ] || fail "Plugin entrypoint not found at $SOURCE_DIR/index.js"

mkdir -p "$(dirname "$INSTALL_DIR")"

if [ -e "$INSTALL_DIR" ]; then
    BACKUP_DIR="${INSTALL_DIR}.backup.$(date +%Y%m%d%H%M%S)"
    info "Existing install found, backing it up to $BACKUP_DIR"
    mv "$INSTALL_DIR" "$BACKUP_DIR"
fi

if cp -R "$SOURCE_DIR" "$INSTALL_DIR"; then
    info "Installed to $INSTALL_DIR"
else
    if [ -n "$BACKUP_DIR" ] && [ -e "$BACKUP_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        mv "$BACKUP_DIR" "$INSTALL_DIR"
    fi
    fail 'Install failed. Previous install was restored if a backup existed.'
fi

VERSION="$(node -p "require('$INSTALL_DIR/package.json').version" 2>/dev/null || sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$INSTALL_DIR/package.json" | head -n 1)"
info "tabby-xterm-fix v${VERSION:-unknown} installed successfully."
info 'Fully restart Tabby, then check the plugin log if needed.'
