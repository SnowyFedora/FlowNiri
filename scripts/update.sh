#!/usr/bin/env bash
# ============================================================
#  FlowNiri — shell update
#  * uses gh (GitHub CLI) only, never curl to the API
#  * replaces files listed in ~/.config/FlowNiri/manifest.txt only
#  * backs every file up into ~/.cache/flow-niri/backup/<timestamp>/
#  * validates niri afterwards and rolls back on failure
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

flow_require gh "$(_m err_gh)" || exit 1
flow_lock || { dlg_error "$(_m busy_title)" "$(_m err_busy)"; exit 1; }

CURRENT=$(head -1 "$FLOW_VERSION_FILE" 2>/dev/null); CURRENT=${CURRENT:-0}

TAGS=$(flow_release_tags)
if [ -z "$TAGS" ]; then
    if ! gh auth status >/dev/null 2>&1; then
        dlg_error "$(_m err_title)" "$(_m err_gh)"
    else
        dlg_info "$(_m update_title)" "$(printf "$(_m update_none_tags)" "$FLOW_RELEASE_REPO")"
    fi
    exit 0
fi

LATEST=$(printf '%s\n' "$TAGS" | head -1)

if [ "$(flow_norm_version "$CURRENT")" = "$(flow_norm_version "$LATEST")" ]; then
    dlg_info "$(_m update_title)" "$(printf "$(_m update_latest)" "$CURRENT")"
    exit 0
fi

if ! dlg_confirm "$(_m update_title)" "$(printf "$(_m update_available)" "$LATEST" "$CURRENT")"; then
    exit 0
fi

TMP=$(mktemp -d /tmp/flow-niri-update.XXXXXX) || exit 1
trap 'rm -rf "$TMP"' EXIT

ZIP=$(flow_release_download "$LATEST" "$TMP") || {
    dlg_error "$(_m err_title)" "$(_m err_gh)"
    exit 1
}

PAYLOAD=$(flow_extract_payload "$ZIP" "$TMP/unpack")
rc=$?
if [ "$rc" -ne 0 ]; then
    dlg_error "$(_m err_title)" "$(_m err_bad_zip)"
    flow_log "update: bad archive rc=$rc"
    exit 1
fi

flow_apply_payload "$PAYLOAD" "$LATEST" "update"
rc=$?
case "$rc" in
    0)
        flow_notify "$(_m app_title)" "$(printf "$(_m notify_update)" "$(flow_norm_version "$LATEST")")" \
            "system-software-update"
        # A release never installs packages; if it needs new ones we only say so.
        MISSING=$(pkg_missing)
        if [ -n "$MISSING" ]; then
            dlg_info "$(_m update_title)" "$(printf "$(_m update_packages)" "$MISSING" "$MISSING")"
        else
            dlg_info "$(_m update_title)" "$(printf "$(_m update_done)" "$(flow_norm_version "$LATEST")")"
        fi
        ;;
    1) : ;;   # validation failed: flow_apply_niri already restored + logged + shown
    *) dlg_error "$(_m err_title)" "$(_m err_bad_zip)" ;;
esac

exit "$rc"
