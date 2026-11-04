#!/usr/bin/env bash
# ============================================================
#  FlowNiri — AI status window (bound to Mod+Shift+A and the
#  Waybar custom/ai-status click).
#  Shows the cached report and offers "Refresh now".
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

flow_has_display || exit 1

while true; do
    TXT=$("$FLOW_SCRIPTS/ai-status.sh" --details 2>/dev/null)
    [ -n "$TXT" ] || TXT="$(_m ai_na)"
    printf '%s\n' "$TXT" | flow_dialog --text-info \
        --title="$(_m ai_details)" \
        --width=640 --height=400 \
        --font="JetBrainsMono Nerd Font 11" \
        --ok-label="$(_m ai_refresh)" \
        --cancel-label="$(_m btn_close)" 2>/dev/null || exit 0
    "$FLOW_SCRIPTS/ai-status.sh" --refresh >/dev/null 2>&1
done
