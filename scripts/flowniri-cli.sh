#!/usr/bin/env bash
# ============================================================
#  FlowNiri — headless action CLI
#
#  Used by the GTK settings app (and anything scriptable). Every command
#  prints a short machine-readable result and never opens a file dialog.
#
#    flowniri-cli.sh status
#    flowniri-cli.sh radius <0|6|12|18>
#    flowniri-cli.sh idle <lock_min> <sleep_min>
#    flowniri-cli.sh defaults <browser|-> <fm|-> <editor|->
#    flowniri-cli.sh lang <ru|en>
#    flowniri-cli.sh waybar-list
#    flowniri-cli.sh waybar-toggle <module>
#    flowniri-cli.sh waybar-restart
#    flowniri-cli.sh ai-toggle <0|1>
#    flowniri-cli.sh ai-agent <id> <0|1>
#    flowniri-cli.sh ai-key <KEY> <value>
#    flowniri-cli.sh ai-cache
#    flowniri-cli.sh cleanup-list
#    flowniri-cli.sh cleanup-move <path>...
#    flowniri-cli.sh hotkeys
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

CONFIG_KDL="$FLOW_CONFIG/niri/config.kdl"
WAYBAR_JSON="$FLOW_CONFIG/waybar/config.jsonc"
WAYBAR_ORDER="$FLOW_DIR/waybar-order.conf"
IDLE_SH="$FLOW_SCRIPTS/idle.sh"
APPS="$HOME/.local/share/applications"

# Right-hand Sidebar modules. Removing one hides it, but the canonical order is
# remembered in waybar-order.conf so switching it back on restores its slot
# instead of appending it to the end of the bar.
waybar_edit() { # --list | --present | --toggle <module> | --order
    python3 - "$WAYBAR_JSON" "$WAYBAR_ORDER" "$@" <<'PY'
import os, re, sys

cfg, order_file, mode = sys.argv[1], sys.argv[2], sys.argv[3]
arg = sys.argv[4] if len(sys.argv) > 4 else None

src = open(cfg, encoding="utf-8").read()
m = re.search(r'("modules-right"\s*:\s*)\[([^\]]*)\]', src)
if not m:
    sys.exit(3)
items = re.findall(r'"([^"]+)"', m.group(2))

order = []
if os.path.exists(order_file):
    order = [l.strip() for l in open(order_file, encoding="utf-8")
             if l.strip() and not l.lstrip().startswith("#")]
for it in items:
    if it not in order:
        order.append(it)


def save_order():
    tmp = order_file + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write("# FlowNiri: right-side Waybar module order.\n")
        fh.write("# Kept when a module is switched off so it returns to the same slot.\n")
        fh.write("\n".join(order) + "\n")
    os.replace(tmp, order_file)


if mode == "--list":
    for mod in order:
        print("%s\t%d" % (mod, 1 if mod in items else 0))
    save_order()
    sys.exit(0)

if mode == "--present":
    print("\n".join(items))
    sys.exit(0)

if mode == "--order":
    print("\n".join(order))
    sys.exit(0)

if mode == "--toggle":
    if not arg:
        sys.exit(2)
    if arg in items:
        items.remove(arg)
    else:
        if arg not in order:
            order.append(arg)
        idx = order.index(arg)
        pos = None
        # insert right after the closest still-visible predecessor
        for prev in reversed(order[:idx]):
            if prev in items:
                pos = items.index(prev) + 1
                break
        if pos is None:  # nothing before it is visible: use the next one
            pos = len(items)
            for nxt in order[idx + 1:]:
                if nxt in items:
                    pos = items.index(nxt)
                    break
        items.insert(pos, arg)

    if "\n" in m.group(2):
        body = "\n" + ",\n".join('        "%s"' % i for i in items) + "\n    "
    else:
        body = ", ".join('"%s"' % i for i in items)
    src = src[:m.start(2)] + body + src[m.end(2):]

    tmp = cfg + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(src)
    os.replace(tmp, cfg)
    save_order()
    print(",".join(items))
    sys.exit(0)

sys.exit(2)
PY
}

restart_idle() {
    pkill -x swayidle 2>/dev/null
    sleep 0.2
    [ -x "$IDLE_SH" ] && setsid "$IDLE_SH" >/dev/null 2>&1 &
}

cmd="${1:-status}"; shift 2>/dev/null || true

case "$cmd" in
    status)
        printf 'version=%s\n' "$(head -1 "$FLOW_VERSION_FILE" 2>/dev/null)"
        printf 'theme=%s\n' "$(flow_theme_id)"
        printf 'lang=%s\n' "$(flow_lang)"
        printf 'radius=%s\n' "$(grep -oE 'geometry-corner-radius[[:space:]]+[0-9]+' "$CONFIG_KDL" | tail -1 | grep -oE '[0-9]+$')"
        printf 'wallpaper=%s\n' "$("$FLOW_SCRIPTS/wallpaper.sh" get)"
        printf 'modules=%s\n' "$(waybar_edit --present | tr '\n' ',' | sed 's/,$//')"
        ;;

    radius)
        px="${1:-12}"
        case "$px" in 0|4|6|8|12|16|18|24) ;; *) echo "bad radius: $px" >&2; exit 2;; esac
        cur=$(grep -oE 'geometry-corner-radius[[:space:]]+[0-9]+' "$CONFIG_KDL" | tail -1 | grep -oE '[0-9]+$')
        if [ "$cur" = "$px" ]; then
            echo "radius=$px unchanged"
            exit 0
        fi
        flow_lock || { echo "busy" >&2; exit 1; }
        bak=$(flow_snapshot)
        sed -i -E "s/^([[:space:]]*)geometry-corner-radius[[:space:]]+[0-9]+/\1geometry-corner-radius $px/" "$CONFIG_KDL"
        flow_apply_niri "$bak" "radius:$px" || exit 1
        echo "radius=$px"
        ;;

    idle)
        lock="$1"; sleep=""; sleep="${2:-}"
        case "${lock}${sleep}" in *[!0-9]*|"") echo "bad arguments" >&2; exit 2;; esac
        [ "$lock" -gt 0 ] && [ "$sleep" -gt 0 ] || { echo "must be > 0" >&2; exit 2; }
        lock_s=$((lock * 60)); sleep_s=$((sleep * 60))
        flow_lock || { echo "busy" >&2; exit 1; }
        cat >"$IDLE_SH" <<EOF
#!/bin/bash
# FlowNiri idle timers — lock ${lock}m, suspend ${sleep}m
swayidle -w \\
  timeout $lock_s 'gtklock' \\
  timeout $sleep_s 'systemctl suspend' \\
  before-sleep 'gtklock'
EOF
        chmod +x "$IDLE_SH"
        restart_idle
        echo "idle=$lock,$sleep"
        ;;

    defaults)
        browser="$1"; fm="$2"; editor="$3"
        [ "$browser" = "-" ] || [ -z "$browser" ] || \
            xdg-settings set default-web-browser "${browser%.desktop}.desktop" 2>/dev/null
        if [ -n "$fm" ] && [ "$fm" != "-" ]; then
            xdg-mime default "${fm%.desktop}.desktop" inode/directory 2>/dev/null
            xdg-settings set default-file-manager "${fm%.desktop}.desktop" 2>/dev/null
        fi
        [ "$editor" = "-" ] || [ -z "$editor" ] || \
            xdg-mime default "${editor%.desktop}.desktop" text/plain 2>/dev/null
        echo "browser=$(xdg-settings get default-web-browser 2>/dev/null | sed 's/\.desktop$//')"
        echo "editor=$(xdg-mime query default text/plain 2>/dev/null | sed 's/\.desktop$//')"
        ;;

    lang)
        flow_set_lang "$1" || { echo "bad lang" >&2; exit 2; }
        echo "lang=$1"
        ;;

    waybar-list)
        waybar_edit --list
        ;;

    waybar-present)
        waybar_edit --present
        ;;

    waybar-toggle)
        waybar_edit --toggle "$1" || { echo "toggle failed" >&2; exit 1; }
        flow_restart_waybar
        waybar_edit --present
        ;;

    waybar-restart)
        flow_restart_waybar
        echo "ok"
        ;;

    ai-toggle)
        flow_conf_set "$FLOW_AI_CONF" ENABLED "$1"
        chmod 600 "$FLOW_AI_CONF" 2>/dev/null
        flow_restart_waybar
        echo "enabled=$1"
        ;;

    ai-agent)
        id="$1"; want="$2"
        cur=$(flow_conf_get "$FLOW_AI_CONF" AGENTS)
        new=""
        for a in ${cur//,/ }; do
            [ "$a" = "$id" ] && continue
            new="${new:+$new,}$a"
        done
        [ "$want" = "1" ] && new="${new:+$new,}$id"
        flow_conf_set "$FLOW_AI_CONF" AGENTS "$new"
        flow_restart_waybar
        echo "agents=$new"
        ;;

    ai-key)
        key="$1"; val="$2"
        [ -n "$key" ] && [ -n "$val" ] || { echo "empty" >&2; exit 2; }
        flow_conf_set "$FLOW_AI_CONF" "$key" "$val"
        chmod 600 "$FLOW_AI_CONF" 2>/dev/null
        echo "key=$key saved"
        ;;

    ai-cache)
        "$FLOW_SCRIPTS/ai-status.sh" --print-cache 2>/dev/null || echo '{}'
        ;;

    cleanup-list)
        "$FLOW_SCRIPTS/cleanup.sh" --list
        ;;

    cleanup-move)
        [ $# -gt 0 ] || { echo "nothing to move" >&2; exit 2; }
        dest="$FLOW_BACKUP_DIR/legacy-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$dest" || exit 1
        n=0
        for p in "$@"; do
            case "$p" in
                "$APPS"/*.desktop|"$FLOW_SCRIPTS"/*.sh)
                    [ -e "$p" ] || continue
                    mv -f -- "$p" "$dest/" && n=$((n + 1))
                    ;;
                *) echo "skip: $p" >&2;;
            esac
        done
        command -v update-desktop-database >/dev/null 2>&1 \
            && update-desktop-database "$APPS" >/dev/null 2>&1
        flow_log "cleanup: moved $n file(s) to $dest"
        echo "moved=$n dest=$dest"
        ;;

    hotkeys)
        "$FLOW_SCRIPTS/hotkeys.sh" --dump
        ;;

    *)
        echo "Unknown command: $cmd" >&2
        sed -n '5,22p' "$0" >&2
        exit 2
        ;;
esac
