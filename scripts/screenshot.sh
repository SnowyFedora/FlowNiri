#!/usr/bin/env bash
# ============================================================
#  FlowNiri — screenshots (grim + slurp + satty)
#  Usage: screenshot.sh [region|full]
#  Result always ends up in the clipboard.
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

MODE="${1:-region}"

have() { command -v "$1" >/dev/null 2>&1; }
have grim || { flow_notify "$(_m app_title)" "grim is not installed" "dialog-error"; exit 1; }

case "$MODE" in
    full)
        have wl-copy || { flow_notify "$(_m app_title)" "wl-copy is not installed" "dialog-error"; exit 1; }
        if grim - | wl-copy; then
            flow_notify "$(_m app_title)" "$(_m notify_shot)" "applets-screenshooter"
        else
            flow_notify "$(_m app_title)" "$(_m notify_shot_fail)" "dialog-error"
            exit 1
        fi
        ;;
    region|*)
        have slurp || { flow_notify "$(_m app_title)" "slurp is not installed" "dialog-error"; exit 1; }
        GEOM=$(slurp -d 2>/dev/null) || exit 0
        [ -n "$GEOM" ] || exit 0
        if have satty; then
            grim -t ppm -g "$GEOM" - | satty -f - \
                --copy-command=wl-copy \
                --actions-on-escape="save-to-clipboard,exit" \
                --disable-notifications
        elif have wl-copy; then
            grim -g "$GEOM" - | wl-copy && flow_notify "$(_m app_title)" "$(_m notify_shot)" "applets-screenshooter"
        else
            grim -g "$GEOM" - >/dev/null && flow_notify "$(_m app_title)" "$(_m notify_shot_fail)" "dialog-error"
        fi
        ;;
esac
