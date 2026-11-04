#!/usr/bin/env bash
# ============================================================
#  FlowNiri — version rollback (called from flowniri-menu.sh)
#  Lists release tags with gh, downloads the chosen ZIP, replaces
#  only manifest files, validates and rolls back config on error.
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
    dlg_info "$(_m rollback_title)" "$(_m rollback_empty)"
    exit 0
fi

ROWS=()
while IFS= read -r tag; do
    [ -n "$tag" ] || continue
    if [ "$(flow_norm_version "$tag")" = "$(flow_norm_version "$CURRENT")" ]; then
        ROWS+=("● $tag  (== $CURRENT)|$tag")
    else
        ROWS+=("  $tag|$tag")
    fi
done <<<"$TAGS"

TAG=$(dlg_list "$(_m rollback_title)" "$(_m rollback_text)" "${ROWS[@]}") || exit 0
[ -n "$TAG" ] || exit 0

if ! dlg_confirm "$(_m rollback_title)" "$(printf "$(_m rollback_confirm)" "$TAG")"; then
    exit 0
fi

TMP=$(mktemp -d /tmp/FlowNiri-rollback.XXXXXX) || exit 1
trap 'rm -rf "$TMP"' EXIT

ZIP=$(flow_release_download "$TAG" "$TMP") || {
    dlg_error "$(_m err_title)" "$(_m err_gh)"
    exit 1
}

PAYLOAD=$(flow_extract_payload "$ZIP" "$TMP/unpack")
rc=$?
if [ "$rc" -ne 0 ]; then
    dlg_error "$(_m err_title)" "$(_m err_bad_zip)"
    flow_log "rollback: bad archive rc=$rc"
    exit 1
fi

flow_apply_payload "$PAYLOAD" "$TAG" "rollback"
rc=$?
case "$rc" in
    0)
        flow_notify "$(_m app_title)" "$(printf "$(_m notify_rollback)" "$TAG")" "edit-undo"
        dlg_info "$(_m rollback_title)" "$(printf "$(_m rollback_done)" "$TAG")"
        ;;
    1) : ;;
    *) dlg_error "$(_m err_title)" "$(_m err_bad_zip)" ;;
esac

exit "$rc"
