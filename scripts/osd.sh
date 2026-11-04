#!/usr/bin/env bash
# ============================================================
#  FlowNiri — OSD / media keys
#  Usage: osd.sh volume-up|volume-down|mute|brightness-up|brightness-down
#
#  The script performs the action itself and then shows an OSD, so
#  volume/brightness keys keep working even without an OSD daemon.
#  Order: swayosd-client (if installed) -> notify-send -> gdbus/mako.
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

ACTION="${1:-}"
SINK="@DEFAULT_AUDIO_SINK@"

have() { command -v "$1" >/dev/null 2>&1; }

show_osd() { # <title> <body> <icon> [swayosd args...]
    local title="$1" body="$2" icon="$3"; shift 3
    if have swayosd-client; then
        swayosd-client "$@" >/dev/null 2>&1 && return 0
    fi
    flow_notify "$title" "$body" "$icon"
}

volume_percent() {
    have wpctl || { printf '%s\n' "?"; return; }
    wpctl get-volume "$SINK" 2>/dev/null | awk '{v=$2*100; printf "%d", v+0.5}'
}

volume_state() {
    have wpctl || { printf '%s\n' ""; return; }
    wpctl get-volume "$SINK" 2>/dev/null | grep -q '\[MUTED\]' && printf '%s\n' "muted"
}

brightness_percent() {
    have brightnessctl || { printf '%s\n' "?"; return; }
    brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'
}

case "$ACTION" in
    volume-up)
        have wpctl && wpctl set-volume "$SINK" 0.1+ -l 1.0
        show_osd "$(_m osd_volume)" "$(volume_percent)%" "audio-volume-high" --output-volume raise
        ;;
    volume-down)
        have wpctl && wpctl set-volume "$SINK" 0.1-
        show_osd "$(_m osd_volume)" "$(volume_percent)%" "audio-volume-low" --output-volume lower
        ;;
    mute)
        have wpctl && wpctl set-mute "$SINK" toggle
        if [ "$(volume_state)" = "muted" ]; then
            show_osd "$(_m osd_volume)" "$(_m osd_mute)" "audio-volume-muted" --output-volume mute-toggle
        else
            show_osd "$(_m osd_volume)" "$(volume_percent)%" "audio-volume-high" --output-volume mute-toggle
        fi
        ;;
    mic-mute)
        have wpctl && wpctl set-mute "@DEFAULT_AUDIO_SOURCE@" toggle
        show_osd "$(_m osd_volume)" "mic" "audio-input-microphone-muted" --input-volume mute-toggle
        ;;
    brightness-up)
        have brightnessctl && brightnessctl --class=backlight set +10% >/dev/null 2>&1
        show_osd "$(_m osd_bright)" "$(brightness_percent)%" "display-brightness" --brightness raise
        ;;
    brightness-down)
        have brightnessctl && brightnessctl --class=backlight set 10%- >/dev/null 2>&1
        show_osd "$(_m osd_bright)" "$(brightness_percent)%" "display-brightness" --brightness lower
        ;;
    *)
        echo "Usage: ${0##*/} volume-up|volume-down|mute|mic-mute|brightness-up|brightness-down" >&2
        exit 2
        ;;
esac
