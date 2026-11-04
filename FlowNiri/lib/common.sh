#!/usr/bin/env bash
# ============================================================
#  FlowNiri — shared library (sourced by every FlowNiri script)
#  No external dependencies: bash, coreutils, sed, python3.
# ============================================================

FLOW_NAME="FlowNiri"
FLOW_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
FLOW_DIR="$FLOW_CONFIG/FlowNiri"
FLOW_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/flow-niri"
FLOW_SCRIPTS="$FLOW_CONFIG/scripts"
FLOW_THEMES="$FLOW_CONFIG/themes"

FLOW_MANIFEST="$FLOW_DIR/manifest.txt"
FLOW_VERSION_FILE="$FLOW_DIR/.version"
FLOW_LANG_FILE="$FLOW_DIR/lang.conf"
FLOW_THEME_FILE="$FLOW_DIR/theme.name"
FLOW_AI_CONF="$FLOW_DIR/ai.conf"
FLOW_AI_CACHE="$FLOW_CACHE/ai-usage.json"
FLOW_BACKUP_DIR="$FLOW_CACHE/backup"
FLOW_ERROR_LOG="$FLOW_CACHE/last_error.log"
FLOW_LOG="$FLOW_CACHE/flow.log"
FLOW_GTK_THEMES="$HOME/.local/share/themes"
FLOW_RELEASE_REPO="SnowyFedora/FlowNiri"
FLOW_LOCK_FILE="/var/lock/flow-niri.lock"

FLOW_PALETTE_KEYS=(BG BG_HARD BG_SOFT BG_SEL BORDER FG FG_STRONG FG_DIM GRAY MUTED \
                   ACCENT ACCENT_2 RED RED_BRIGHT GREEN GREEN_BRIGHT BLUE PURPLE ORANGE)

mkdir -p "$FLOW_CACHE" "$FLOW_BACKUP_DIR" 2>/dev/null

# ---------------------------------------------------------------- logging ---
flow_log() {
    printf '[%s] %s: %s\n' "$(date '+%F %T')" "${0##*/}" "$*" >>"$FLOW_LOG" 2>/dev/null
}

# --------------------------------------------------------------- locking ----
# Tries /var/lock first (as requested), falls back to the user cache directory
# because /var/lock is normally not writable for a regular user.
flow_lock() {
    local file="$FLOW_LOCK_FILE"
    if ! { : >>"$file"; } 2>/dev/null; then
        file="$FLOW_CACHE/flow-niri.lock"
    fi
    exec 9>"$file" 2>/dev/null || return 1
    flock -n 9 || return 1
    return 0
}

# ------------------------------------------------------------- i18n ---------
flow_lang() {
    local l
    l=$(sed -n 's/^LANG=//p' "$FLOW_LANG_FILE" 2>/dev/null | head -1)
    [ -n "$l" ] || l="ru"
    printf '%s\n' "$l"
}

flow_i18n_load() {
    declare -gA M
    M=()
    local l f
    l=$(flow_lang)
    f="$FLOW_DIR/i18n/$l.conf"
    [ -f "$f" ] || f="$FLOW_DIR/i18n/ru.conf"
    # shellcheck disable=SC1090
    [ -f "$f" ] && . "$f"
}

flow_set_lang() {
    case "$1" in
        ru|en) printf 'LANG=%s\n' "$1" >"$FLOW_LANG_FILE";;
        *) return 1;;
    esac
}

# ------------------------------------------------------------- config ------
flow_conf_get() { # <file> <key>
    sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1
}

flow_conf_set() { # <file> <key> <value>
    local file="$1" key="$2" val="$3" tmp
    [ -f "$file" ] || : >"$file"
    tmp=$(mktemp) || return 1
    if grep -q "^$key=" "$file" 2>/dev/null; then
        awk -v k="$key" -v v="$val" 'BEGIN{FS=OFS="="} $1==k{print k "=" v; next} {print}' "$file" >"$tmp"
    else
        cp "$file" "$tmp"
        printf '%s=%s\n' "$key" "$val" >>"$tmp"
    fi
    cat "$tmp" >"$file" && rm -f "$tmp"
}

# ----------------------------------------------------------- dialogs --------
flow_has_display() { [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; }

flow_theme_id() {
    local id
    id=$(head -1 "$FLOW_THEME_FILE" 2>/dev/null)
    [ -n "$id" ] || id="gruvbox-dark"
    printf '%s\n' "$id"
}

# Light|dark mode of the active theme: MODE= first, then the theme id,
# then the luminance of BG. Mirrors apply_theme-switcher.sh.
flow_theme_mode() {
    local id raw bg r g b lum
    id=$(flow_theme_id)
    raw=$(flow_theme_field "$id" MODE | tr 'A-Z' 'a-z')
    case "$raw" in
        *light*|*white*|*day*|*светл*|*бел*) printf 'light\n'; return ;;
        *dark*|*night*|*black*|*midnight*|*темн*|*тёмн*|*черн*|*чёрн*) printf 'dark\n'; return ;;
    esac
    raw=$(printf '%s' "$id" | tr 'A-Z' 'a-z')
    case "$raw" in
        *light*|*white*|*day*|*светл*|*бел*) printf 'light\n'; return ;;
        *dark*|*night*|*black*|*midnight*|*темн*|*тёмн*|*черн*|*чёрн*) printf 'dark\n'; return ;;
    esac
    bg=$(flow_theme_field "$id" BG | tr -d '#')
    if [[ "$bg" =~ ^[0-9a-fA-F]{6}$ ]]; then
        r=$((16#${bg:0:2})); g=$((16#${bg:2:2})); b=$((16#${bg:4:2}))
        lum=$(((r * 299 + g * 587 + b * 114) / 1000))
        [ "$lum" -ge 128 ] && { printf 'light\n'; return; }
    fi
    printf 'dark\n'
}

# Standard Adwaita only: GTK apps follow color-scheme, never the palette.
flow_gtk_theme() {
    if [ "$(flow_theme_mode)" = "light" ]; then
        printf 'Adwaita\n'
    else
        printf 'Adwaita-dark\n'
    fi
}

flow_dialog() { # low-level: every zenity call goes through here
    flow_has_display || return 1
    # No GTK_THEME override: dialogs use the system Adwaita and follow
    # org.gnome.desktop.interface color-scheme (set by the theme applier).
    GTK_USE_PORTAL=1 zenity "$@"
}

_m() { # safe message lookup: _m key fallback
    local v="${M[$1]}"
    [ -n "$v" ] || v="${2:-$1}"
    printf '%s\n' "$v"
}

dlg_info() {
    flow_dialog --info --no-wrap --title="${1:-$(_m app_title)}" --text="$2" \
        --width=480 --ok-label="$(_m btn_ok)" 2>/dev/null
}

dlg_error() {
    flow_dialog --error --title="${1:-$(_m app_title)}" --text="$2" \
        --width=560 --ok-label="$(_m btn_ok)" 2>/dev/null
}

dlg_warn() {
    flow_dialog --warning --title="${1:-$(_m app_title)}" --text="$2" \
        --width=520 --ok-label="$(_m btn_ok)" 2>/dev/null
}

dlg_confirm() { # <title> <text>; exit 0 = yes
    flow_dialog --question --title="$1" --text="$2" --width=480 \
        --ok-label="$(_m btn_yes)" --cancel-label="$(_m btn_no)" 2>/dev/null
}

# dlg_list <title> <text> <"label|id">...
# Returns the id of the selected row, exit 1 on Cancel.
dlg_list() {
    local title="$1" text="$2"; shift 2
    [ $# -gt 0 ] || return 1
    local args=() row
    for row in "$@"; do
        args+=("${row%%|*}" "${row#*|}")
    done
    flow_dialog --list --title="$title" --text="$text" \
        --column="$(_m col_item)" --column="id" \
        --hide-column=2 --print-column=2 --hide-header \
        --width=580 --height=560 \
        --ok-label="$(_m btn_ok)" --cancel-label="$(_m btn_cancel)" \
        "${args[@]}" 2>/dev/null
}

dlg_forms() { # passthrough, unified style
    flow_dialog --forms --width=520 --separator='|' \
        --ok-label="$(_m btn_ok)" --cancel-label="$(_m btn_cancel)" "$@" 2>/dev/null
}

dlg_file() { # <title> <filter label> <patterns>
    flow_dialog --file-selection --title="$1" --filename="$HOME/" \
        --file-filter="$2 | $3" --ok-label="$(_m btn_ok)" \
        --cancel-label="$(_m btn_cancel)" 2>/dev/null
}

# -------------------------------------------------------- notifications -----
flow_notify() { # <title> <body> [icon]
    local title="$1" body="$2" icon="${3:-dialog-information}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a FlowNiri -i "$icon" "$title" "$body" 2>/dev/null && return 0
    fi
    if command -v gdbus >/dev/null 2>&1; then
        gdbus call --session --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.Notify \
            "FlowNiri" 0 "$icon" "$title" "$body" "[]" "{}" 4000 >/dev/null 2>&1 && return 0
    fi
    return 1
}

# -------------------------------------------------------------- themes ------
flow_theme_ids() {
    local f
    for f in "$FLOW_THEMES"/*.theme; do
        [ -f "$f" ] || continue
        f=$(basename "$f")
        printf '%s\n' "${f%.theme}"
    done
}

flow_theme_field() { # <id> <KEY>
    sed -n "s/^$2=//p" "$FLOW_THEMES/$1.theme" 2>/dev/null | head -1
}

flow_theme_label() { # <id> -> localized name (quotes stripped)
    local v
    v=$(flow_theme_field "$1" "NAME_$(flow_lang | tr 'a-z' 'A-Z')")
    [ -n "$v" ] || v=$(flow_theme_field "$1" NAME_EN)
    [ -n "$v" ] || v="$1"
    v="${v%\"}"; v="${v#\"}"
    printf '%s\n' "$v"
}

# FlowNiri no longer generates a recoloured GTK theme: GTK apps must use the
# stock Adwaita (light/dark via color-scheme). This stays as a cleanup hook
# so directories left by older versions disappear; it never writes CSS.
flow_generate_gtk_theme() { # <theme-id> (ignored)
    rm -rf "$FLOW_GTK_THEMES"/FlowNiri-* 2>/dev/null
    return 0
}

# -------------------------------------------------------- manifest ---------
flow_manifest_entries() {
    [ -f "$FLOW_MANIFEST" ] || return 0
    sed -e 's/\r$//' "$FLOW_MANIFEST" \
        | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        | grep -v '^$'
}

# User state files: never overwritten by update/rollback.
flow_is_state_file() {
    case "$1" in
        FlowNiri/lang.conf|FlowNiri/theme.name|FlowNiri/ai.conf) return 0;;
    esac
    return 1
}

# Copies every existing manifest file into ~/.cache/flow-niri/backup/<ts>/
# Prints the backup directory.
flow_snapshot() {
    local dir rel
    dir="$FLOW_BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$dir" || return 1
    while IFS= read -r rel; do
        [ -f "$FLOW_CONFIG/$rel" ] || continue
        mkdir -p "$dir/$(dirname "$rel")" 2>/dev/null
        cp -a "$FLOW_CONFIG/$rel" "$dir/$rel" 2>/dev/null
    done <<<"$(flow_manifest_entries)"
    cp -a "$FLOW_MANIFEST" "$dir/manifest.txt" 2>/dev/null
    printf '%s\n' "$dir"
}

flow_restore() { # <backup dir>
    local dir="$1" rel
    [ -d "$dir" ] || return 1
    while IFS= read -r rel; do
        [ -f "$dir/$rel" ] || continue
        mkdir -p "$FLOW_CONFIG/$(dirname "$rel")" 2>/dev/null
        cp -a "$dir/$rel" "$FLOW_CONFIG/$rel" 2>/dev/null
    done <<<"$(flow_manifest_entries)"
}

# ------------------------------------------------------------ niri ---------
flow_reload_niri() { niri msg action load-config-file >/dev/null 2>&1; }

flow_restart_waybar() {
    pkill -x waybar 2>/dev/null
    sleep 0.4
    if pgrep -x niri >/dev/null 2>&1; then
        # 9>&- is essential: waybar must not inherit the flock descriptor and
        # hold the FlowNiri lock for the whole session.
        env -u GTK_THEME setsid waybar >/dev/null 2>&1 9>&- &
    fi
}

flow_restart_fuzzel() { pkill -x fuzzel 2>/dev/null; }

# Validates the live niri config. On failure: restores the snapshot, re-checks,
# writes both errors to last_error.log, shows a localized message and does NOT
# reload the compositor or end the session.
flow_apply_niri() { # <backup dir> <source label>
    local bak="$1" src="$2" out rc out2 rc2
    out=$(niri validate 2>&1); rc=$?
    if [ "$rc" -ne 0 ]; then
        flow_log "niri validate failed ($src)"
        flow_restore "$bak"
        out2=$(niri validate 2>&1); rc2=$?
        {
            printf '=== FlowNiri error log ===\n'
            printf 'when:   %s\nsource: %s\nbackup: %s\n\n' "$(date '+%F %T')" "$src" "$bak"
            printf -- '--- niri validate (before restore, exit=%s) ---\n%s\n\n' "$rc" "$out"
            printf -- '--- niri validate (after restore, exit=%s) ---\n%s\n' "$rc2" "$out2"
        } >"$FLOW_ERROR_LOG"
        flow_generate_gtk_theme "$(flow_theme_id)" >/dev/null 2>&1
        dlg_error "$(_m err_title)" "$(printf '%s\n\n%s\n%s' "$(_m err_invalid_config)" "$FLOW_ERROR_LOG" "$bak")"
        return 1
    fi
    flow_reload_niri
    return 0
}

# ------------------------------------------------------------ misc ---------
flow_require() { # <cmd> <localized message>
    command -v "$1" >/dev/null 2>&1 && return 0
    dlg_error "$(_m err_title)" "$2"
    return 1
}

flow_pkg_hint() { # prints the pacman command for missing FlowNiri dependencies
    printf 'sudo pacman -S --needed --noconfirm github-cli unzip jq libnotify wf-recorder udiskie pacman-contrib swayosd\n'
}

# Packages from FlowNiri/packages.txt that are not installed (empty if none).
pkg_missing() {
    local list
    [ -f "$FLOW_DIR/packages.txt" ] || return 0
    list=$(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$FLOW_DIR/packages.txt" \
        | grep -v '^$' | tr '\n' ' ')
    [ -n "$list" ] || return 0
    command -v pacman >/dev/null 2>&1 || return 0
    # shellcheck disable=SC2086
    pacman -T $list 2>/dev/null
}

# --------------------------------------------------------- releases --------
# All GitHub access goes through gh (no curl to the API).
flow_norm_version() { printf '%s\n' "${1#v}"; }

flow_release_tags() { # newest first
    gh release list -R "$FLOW_RELEASE_REPO" --limit 40 --json tagName,createdAt \
        --jq 'sort_by(.createdAt) | reverse | .[] | .tagName' 2>/dev/null
}

flow_release_download() { # <tag> <destdir> -> prints the zip path
    local tag="$1" dest="$2" out
    mkdir -p "$dest" || return 1
    gh release download "$tag" -R "$FLOW_RELEASE_REPO" -p "*.zip" -D "$dest" >/dev/null 2>&1 || return 1
    out=$(find "$dest" -maxdepth 1 -name '*.zip' -print -quit 2>/dev/null)
    [ -n "$out" ] || return 1
    printf '%s\n' "$out"
}

# Extracts a release zip and verifies the FlowNiri/ folder is present
# (GitHub auto-generated source archives are rejected).
flow_extract_payload() { # <zip> <destdir> -> prints <destdir>/FlowNiri
    local zip="$1" dest="$2" rc
    mkdir -p "$dest" || return 1
    python3 - "$zip" "$dest" <<'PY'
import os, sys, zipfile
zip_path, dest = sys.argv[1], sys.argv[2]
try:
    with zipfile.ZipFile(zip_path) as z:
        names = z.namelist()
        if not any(n.rstrip('/') == "FlowNiri" or n.startswith("FlowNiri/") for n in names):
            sys.exit(21)
        root = os.path.realpath(dest)
        for n in names:
            target = os.path.realpath(os.path.join(dest, n))
            if target != root and not target.startswith(root + os.sep):
                sys.exit(22)
        z.extractall(dest)
except zipfile.BadZipFile:
    sys.exit(23)
except Exception:
    sys.exit(24)
sys.exit(0)
PY
    rc=$?
    [ "$rc" -eq 0 ] || return "$rc"
    [ -d "$dest/FlowNiri" ] || return 21
    printf '%s\n' "$dest/FlowNiri"
}

# Copies manifest files from a release payload into ~/.config, backing up
# everything first, then validates. Returns 0 ok, 1 validate failure, 2 io.
flow_apply_payload() { # <payload root> <version>
    local payload="$1" version="$2" bak rel
    local -a entries=()
    bak=$(flow_snapshot) || return 2

    # Merge in the release manifest so brand-new files are picked up too.
    if [ -f "$payload/FlowNiri/manifest.txt" ]; then
        while IFS= read -r rel; do
            entries+=("$rel")
        done <<<"$(sed -e 's/\r$//' "$payload/FlowNiri/manifest.txt" \
                        | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                        | grep -v '^$')"
    fi
    while IFS= read -r rel; do
        printf '%s\n' "${entries[@]}" | grep -qxF "$rel" || entries+=("$rel")
    done <<<"$(flow_manifest_entries)"

    for rel in "${entries[@]}"; do
        [ -n "$rel" ] || continue
        [ -f "$payload/$rel" ] || continue
        flow_is_state_file "$rel" && continue
        mkdir -p "$FLOW_CONFIG/$(dirname "$rel")" || return 2
        cp -a "$payload/$rel" "$FLOW_CONFIG/$rel" || return 2
    done

    # scripts must stay executable
    while IFS= read -r rel; do
        case "$rel" in scripts/*.sh|FlowNiri/lib/*.sh) chmod +x "$FLOW_CONFIG/$rel" 2>/dev/null;; esac
    done <<<"$(flow_manifest_entries)"

    printf '%s\n' "$(flow_norm_version "$version")" >"$FLOW_VERSION_FILE"

    # desktop entries live outside ~/.config and are installed explicitly
    if [ -d "$payload/FlowNiri/applications" ]; then
        mkdir -p "$HOME/.local/share/applications"
        cp -f "$payload/FlowNiri/applications"/*.desktop "$HOME/.local/share/applications/" 2>/dev/null
        # releases are built on the author's machine: rewrite the home path
        for f in "$HOME/.local/share/applications"/flowniri-*.desktop; do
            [ -f "$f" ] && sed -i "s|/home/[^/]*/\\.config|$HOME/.config|g" "$f"
        done
        command -v update-desktop-database >/dev/null 2>&1 \
            && update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1
    fi

    if [ -f "$FLOW_CONFIG/systemd/user/flow-niri-ai-active.timer" ]; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi

    flow_apply_niri "$bak" "$3:$version" || return 1
    flow_restart_waybar
    return 0
}
