#!/usr/bin/env bash
# ============================================================
#  FlowNiri — wallpaper backend
#
#  Usage:
#    wallpaper.sh get                 -> "<path>|<mode>"
#    wallpaper.sh set <file> [mode]   -> apply live + persist in niri config
#    wallpaper.sh list                -> candidate images (one per line)
#    wallpaper.sh modes               -> supported modes
#
#  Modes: fill fit stretch center tile
#  * only the `spawn-at-startup "swaybg" ...` line of niri/config.kdl is
#    touched; the whole config is validated and rolled back on failure;
#  * swaybg is restarted through `niri msg action spawn` (no session restart);
#  * state is remembered in ~/.config/FlowNiri/wallpaper.conf.
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

CONFIG_KDL="$FLOW_CONFIG/niri/config.kdl"
WALL_CONF="$FLOW_DIR/wallpaper.conf"
MODES="fill fit stretch center tile"

# ---------------------------------------------------------------- helpers --
current_mode() {
    local m
    m=$(grep -oE 'spawn-at-startup "swaybg"[^#]*"-m" "[a-z]+"' "$CONFIG_KDL" 2>/dev/null \
        | head -1 | grep -oE '"[a-z]+"$' | tr -d '"')
    [ -n "$m" ] || m=$(flow_conf_get "$WALL_CONF" MODE)
    [ -n "$m" ] || m="fill"
    printf '%s\n' "$m"
}

current_path() {
    local p
    p=$(grep -oE 'spawn-at-startup "swaybg"[^#]*"-i" "[^"]+"' "$CONFIG_KDL" 2>/dev/null \
        | head -1 | sed -E 's/.*"-i" "([^"]+)"$/\1/')
    [ -n "$p" ] || p=$(flow_conf_get "$WALL_CONF" PATH)
    printf '%s\n' "$p"
}

restart_swaybg() { # <mode> <path>
    local mode="$1" path="$2"
    command -v swaybg >/dev/null 2>&1 || {
        flow_notify "$(_m app_title)" "$(_m wallpaper_no_swaybg)" "dialog-warning"
        return 0
    }
    pkill -x swaybg 2>/dev/null
    sleep 0.25
    if command -v niri >/dev/null 2>&1 && niri msg version >/dev/null 2>&1; then
        niri msg action spawn -- swaybg -m "$mode" -i "$path" >/dev/null 2>&1
    else
        setsid swaybg -m "$mode" -i "$path" >/dev/null 2>&1 &
    fi
}

set_wallpaper() { # <file> [mode]
    local file="$1" mode="${2:-}" abs bak esc old_mode
    [ -n "$file" ] || return 2
    case "$file" in
        "~/"*) file="$HOME/${file#\~/}";;
    esac
    [ -f "$file" ] || { dlg_error "$(_m err_title)" "$(printf "$(_m wallpaper_missing)" "$file")"; return 2; }
    abs=$(readlink -f -- "$file" 2>/dev/null) || abs="$file"

    [ -n "$mode" ] || mode=$(current_mode)
    case " $MODES " in *" $mode "*) ;; *) mode="fill";; esac

    old_mode=$(current_mode)
    flow_lock || { dlg_error "$(_m busy_title)" "$(_m err_busy)"; return 1; }

    bak=$(flow_snapshot)

    # Escape for sed replacement (backslash, & and the | delimiter).
    esc=${abs//\\/\\\\}; esc=${esc//&/\\&}; esc=${esc//|/\\|}

    if grep -qE '^[[:space:]]*spawn-at-startup[[:space:]]+"swaybg"' "$CONFIG_KDL" 2>/dev/null; then
        sed -i -E "s|^[[:space:]]*spawn-at-startup[[:space:]]+\"swaybg\".*|    spawn-at-startup \"swaybg\" \"-m\" \"$mode\" \"-i\" \"$esc\"|" "$CONFIG_KDL"
    else
        printf '\n    spawn-at-startup "swaybg" "-m" "%s" "-i" "%s"\n' "$mode" "$esc" >>"$CONFIG_KDL"
    fi

    flow_apply_niri "$bak" "wallpaper:$mode" || return 1

    flow_conf_set "$WALL_CONF" PATH "$abs"
    flow_conf_set "$WALL_CONF" MODE "$mode"

    restart_swaybg "$mode" "$abs"
    flow_log "wallpaper: $abs (mode=$mode, was=$old_mode)"
    flow_notify "$(_m app_title)" "$(_m wallpaper_done)" "preferences-desktop-wallpaper"
    printf '%s|%s\n' "$abs" "$mode"
}

list_images() {
    local dir f
    for dir in "$HOME/Pictures" "$HOME/Wallpapers" "$HOME/Downloads"; do
        [ -d "$dir" ] || continue
        find "$dir" -maxdepth 2 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
            2>/dev/null | sort | head -200
    done
}

case "${1:-get}" in
    get)
        printf '%s|%s\n' "$(current_path)" "$(current_mode)"
        ;;
    set)
        shift
        set_wallpaper "$@" || exit $?
        ;;
    list)
        list_images
        ;;
    modes)
        printf '%s\n' "$MODES"
        ;;
    -h|--help)
        sed -n '2,20p' "$0"
        ;;
    *)
        echo "Usage: ${0##*/} get|set <file> [mode]|list|modes" >&2
        exit 2
        ;;
esac
