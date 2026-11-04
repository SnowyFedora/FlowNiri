#!/usr/bin/env bash
# ============================================================
#  FlowNiri — safe cleanup
#  NEVER deletes anything automatically. Builds a candidate list:
#    * .desktop files created by FlowNiri (or by the legacy installer)
#    * FlowNiri scripts in ~/.config/scripts that are no longer called
#  Shows it with zenity, asks for confirmation, deletes only the ticked
#  entries. Packages, dependencies and system files are never touched.
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

APPS="$HOME/.local/share/applications"
SCRIPTS="$FLOW_SCRIPTS"

# Desktop entries installed by the legacy install.sh, superseded by FlowNiri.
LEGACY_DESKTOPS=(
    niri-idle-settings.desktop
    niri-keybind-editor.desktop
    default-apps.desktop
    wallpaper-picker.desktop
    power-profile.desktop
)

# Keep these: they are part of the current shell.
KEEP_DESKTOPS=(flowniri-menu.desktop flowniri-ai.desktop)

CANDIDATES=()   # "label|absolute path"

# ---------------------------------------------------------------- desktops --
for name in "${LEGACY_DESKTOPS[@]}"; do
    if [ -f "$APPS/$name" ]; then
        CANDIDATES+=("desktop: $name|$APPS/$name")
    fi
done

for f in "$APPS"/flowniri-*.desktop; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    skip=0
    for k in "${KEEP_DESKTOPS[@]}"; do [ "$name" = "$k" ] && skip=1; done
    [ "$skip" -eq 0 ] || continue
    exec_line=$(sed -n 's/^Exec=//p' "$f" | head -1)
    target=$(printf '%s\n' "$exec_line" | grep -oE '~?/[^ ]+\.sh' | head -1)
    target="${target/#\~/$HOME}"
    if [ -n "$target" ] && [ ! -f "$target" ]; then
        CANDIDATES+=("desktop: $name (script missing)|$f")
    fi
done

# ----------------------------------------------------------------- scripts --
is_referenced() { # <basename>
    local base="$1" f
    grep -rIl --exclude=hotkeys.sh -- "$base" \
        "$FLOW_CONFIG/niri" "$FLOW_CONFIG/waybar" "$APPS" \
        "$SCRIPTS" "$FLOW_CONFIG/FlowNiri" 2>/dev/null \
        | grep -v -E "/${base//./\\.}$" | grep -q .
}

is_owned() {
    flow_manifest_entries | grep -qxF "scripts/$1"
}

for f in "$SCRIPTS"/*.sh; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    is_owned "$base" && continue
    if ! is_referenced "$base"; then
        CANDIDATES+=("script: $base (not referenced)|$f")
    fi
done

if [ "${1:-}" = "--list" ]; then
    [ "${#CANDIDATES[@]}" -gt 0 ] && printf '%s\n' "${CANDIDATES[@]}"
    exit 0
fi

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
    dlg_info "$(_m cleanup_title)" "$(_m cleanup_none)"
    exit 0
fi

ARGS=()
for row in "${CANDIDATES[@]}"; do
    ARGS+=("FALSE" "${row%%|*}" "${row#*|}")
done

SELECTED=$(flow_dialog --list --checklist \
    --title="$(_m cleanup_title)" --text="$(_m cleanup_text)" \
    --column="" --column="$(_m col_item)" --column="path" \
    --hide-column=3 --print-column=3 --separator=$'\n' \
    --width=720 --height=560 \
    --ok-label="$(_m btn_ok)" --cancel-label="$(_m btn_cancel)" \
    "${ARGS[@]}" 2>/dev/null) || exit 0

[ -n "$SELECTED" ] || exit 0

if ! dlg_confirm "$(_m cleanup_title)" "$(_m cleanup_confirm)"; then
    exit 0
fi

COUNT=0
while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
        "$APPS"/*.desktop|"$SCRIPTS"/*.sh)
            rm -f -- "$path" && COUNT=$((COUNT + 1))
            ;;
        *) continue;;   # anything outside the allowed paths is ignored
    esac
done <<<"$SELECTED"

command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$APPS" >/dev/null 2>&1

flow_log "cleanup: removed $COUNT file(s)"
dlg_info "$(_m cleanup_title)" "$(printf "$(_m cleanup_done)" "$COUNT")"
