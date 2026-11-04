#!/usr/bin/env bash
# ============================================================
#  FlowNiri — system update (runs inside a terminal window)
#  pacman -Syu, then the integrity check pacman -Dk, then paccache.
#  Config backup is created by flowniri-menu.sh before this runs.
#  Package rollback is NOT performed — only configs can be restored.
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"

LOG="$FLOW_CACHE/last-system-update.log"
STATUS_FILE="$FLOW_CACHE/last-system-update.status"
mkdir -p "$FLOW_CACHE"
: >"$LOG"

exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo " FlowNiri system update — $(date '+%F %T')"
echo "============================================================"
echo

if ! command -v pacman >/dev/null 2>&1; then
    echo "[ERROR] pacman not found"
    printf '1\n' >"$STATUS_FILE"
    exit 1
fi

echo "== sudo pacman -Syu =="
sudo pacman -Syu
SYU=$?

echo
echo "== sudo pacman -Dk (database integrity check) =="
sudo pacman -Dk
DK=$?

if command -v paccache >/dev/null 2>&1; then
    echo
    echo "== sudo paccache -r (keep the 3 most recent versions) =="
    sudo paccache -rk3 || true
fi

echo
if [ "$SYU" -eq 0 ] && [ "$DK" -eq 0 ]; then
    echo "== Result: OK (pacman -Syu=$SYU, pacman -Dk=$DK) =="
    printf '0\n' >"$STATUS_FILE"
    exit 0
fi

echo "== Result: FAILED (pacman -Syu=$SYU, pacman -Dk=$DK) =="
echo "FlowNiri can restore ~/.config from the backup, but NOT system packages."
printf '1\n' >"$STATUS_FILE"
exit 1
