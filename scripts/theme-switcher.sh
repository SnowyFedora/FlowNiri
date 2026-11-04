#!/usr/bin/env bash
# ============================================================
#  FlowNiri — unified theme switcher
#  Usage: theme-switcher.sh --list
#         theme-switcher.sh [--silent] <theme-id>
#
#  Reads ~/.config/themes/<id>.theme and swaps the palette inside
#  waybar/style.css, fuzzel/fuzzel.ini and niri/config.kdl.
#  Colours are replaced through unique placeholders, so two themes
#  that share hex values can never cascade.
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

SILENT=0
THEME_ID=""

for arg in "$@"; do
    case "$arg" in
        --list) flow_theme_ids; exit 0;;
        --silent) SILENT=1;;
        -h|--help) sed -n '2,14p' "$0"; exit 0;;
        -*) dlg_error "$(_m err_title)" "Unknown option: $arg"; exit 2;;
        *) THEME_ID="$arg";;
    esac
done

[ -n "$THEME_ID" ] || { dlg_error "$(_m err_title)" "Usage: ${0##*/} <theme-id>"; exit 2; }
[ -f "$FLOW_THEMES/$THEME_ID.theme" ] || {
    dlg_error "$(_m err_title)" "Theme not found: $THEME_ID"
    exit 2
}

flow_require zenity "$(_m err_no_zenity)" || exit 1

# --- theme completeness check (all palette keys must exist & be unique) ----
check_theme() {
    local id="$1" key val seen=""
    for key in "${FLOW_PALETTE_KEYS[@]}"; do
        val=$(flow_theme_field "$id" "$key")
        if [ -z "$val" ]; then
            dlg_error "$(_m err_title)" "Theme '$id' is missing key $key"
            return 1
        fi
        if printf '%s\n' "$seen" | grep -qx "$val"; then
            dlg_error "$(_m err_title)" "Theme '$id' has a duplicate colour $val ($key)"
            return 1
        fi
        seen="$seen$val"$'\n'
    done
    return 0
}

check_theme "$THEME_ID" || exit 1

flow_lock || { dlg_error "$(_m busy_title)" "$(_m err_busy)"; exit 1; }

OLD_ID="$(flow_theme_id)"
if [ "$OLD_ID" = "$THEME_ID" ]; then
    flow_generate_gtk_theme "$THEME_ID" >/dev/null 2>&1
    [ "$SILENT" -eq 1 ] || flow_notify "$(_m app_title)" "$(printf "$(_m notify_theme)" "$(flow_theme_label "$THEME_ID")")"
    exit 0
fi

BAK="$(flow_snapshot)"
FILES=(
    "$FLOW_CONFIG/waybar/style.css"
    "$FLOW_CONFIG/fuzzel/fuzzel.ini"
    "$FLOW_CONFIG/niri/config.kdl"
)

swap_colors() { # <from-id> <to-id> <files...>
    local from="$1" to="$2"; shift 2
    local -a ph=() ph2=()
    local key oval nval i=0
    for key in "${FLOW_PALETTE_KEYS[@]}"; do
        oval=$(flow_theme_field "$from" "$key" | tr 'A-F' 'a-f')
        nval=$(flow_theme_field "$to"   "$key" | tr 'A-F' 'a-f')
        [ -n "$oval" ] && [ -n "$nval" ] || continue
        [ "$oval" = "$nval" ] && continue
        ph+=( -e "s/\\b${oval}([0-9a-f]{2})?\\b/__FN${i}__\\1/gI" )
        ph2+=( -e "s/__FN${i}__/${nval}/gI" )
        i=$((i + 1))
    done
    [ "${#ph[@]}" -eq 0 ] && return 0
    sed -i -E "${ph[@]}"  "$@" || return 1
    sed -i -E "${ph2[@]}" "$@" || return 1
    return 0
}

if ! swap_colors "$OLD_ID" "$THEME_ID" "${FILES[@]}"; then
    flow_restore "$BAK"
    dlg_error "$(_m err_title)" "sed failed while swapping colours; files restored."
    exit 1
fi

if grep -l "__FN" "${FILES[@]}" >/dev/null 2>&1; then
    flow_restore "$BAK"
    dlg_error "$(_m err_title)" "Palette placeholders were not resolved; files restored."
    exit 1
fi

# --- validate niri; on failure flow_apply_niri restores and logs ----------
if ! flow_apply_niri "$BAK" "theme:$THEME_ID"; then
    exit 1
fi

printf '%s\n' "$THEME_ID" >"$FLOW_THEME_FILE"
flow_generate_gtk_theme "$THEME_ID" >/dev/null 2>&1

flow_restart_waybar
flow_restart_fuzzel
flow_log "theme applied: $OLD_ID -> $THEME_ID"

if [ "$SILENT" -eq 0 ]; then
    flow_notify "$(_m app_title)" \
        "$(printf "$(_m notify_theme)" "$(flow_theme_label "$THEME_ID")")" \
        "preferences-desktop-theme"
fi
exit 0
