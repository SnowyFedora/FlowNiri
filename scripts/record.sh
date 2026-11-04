#!/usr/bin/env bash
# ============================================================
#  FlowNiri — screen recording toggle (wf-recorder, optional)
#  Usage: record.sh [toggle|stop]
#  Records the region picked with slurp into ~/Videos/FlowNiri.
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

OUTDIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/FlowNiri"
STATE="$FLOW_CACHE/recording.path"

stop_recording() {
    if pgrep -x wf-recorder >/dev/null 2>&1; then
        pkill -INT -x wf-recorder 2>/dev/null
        sleep 0.3
        flow_notify "$(_m app_title)" "$(_m notify_rec_stop)" "media-record"
        rm -f "$STATE"
        return 0
    fi
    return 1
}

if ! command -v wf-recorder >/dev/null 2>&1; then
    flow_notify "$(_m app_title)" "$(_m notify_rec_missing)" "dialog-warning"
    exit 1
fi

MODE="${1:-toggle}"
if [ "$MODE" = "stop" ] || pgrep -x wf-recorder >/dev/null 2>&1; then
    stop_recording && exit 0
    [ "$MODE" = "stop" ] && exit 0
fi

GEOM=$(slurp -d 2>/dev/null) || exit 0
[ -n "$GEOM" ] || exit 0

mkdir -p "$OUTDIR" || exit 1
FILE="$OUTDIR/flow-$(date +%Y-%m-%d_%H-%M-%S).mp4"

setsid wf-recorder -g "$GEOM" -f "$FILE" >/dev/null 2>&1 &
printf '%s\n' "$FILE" >"$STATE"
sleep 0.4

if pgrep -x wf-recorder >/dev/null 2>&1; then
    flow_notify "$(_m app_title)" "$(_m notify_rec_start): $FILE" "media-record"
    exit 0
fi

flow_notify "$(_m app_title)" "$(_m notify_rec_missing)" "dialog-warning"
rm -f "$STATE"
exit 1
