#!/usr/bin/env bash
# ============================================================
#  FlowNiri — multi-agent AI usage monitor
#
#  Modes:
#    --refresh             collect agent state now, write cache
#    --waybar              print Waybar JSON from cache (fast)
#    --details             print a human readable report
#    --mode active|idle    systemd timer gate (see flow-niri-ai-*.timer)
#
#  Hybrid monitoring: a process check (pgrep) plus real session activity
#  (recent files in the agent's data directory). A running but idle agent
#  is polled every 5 minutes, a fully idle machine every 15 minutes.
#  Cache: ~/.cache/flow-niri/ai-usage.json (atomic, flock-protected).
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

ACTIVE_T=300   # seconds: session counts as active
IDLE_GATE=300  # seconds: poll interval for a running-but-idle agent
ALL_GATE=900   # seconds: poll interval when nothing runs

MODE="--waybar"
ARG_MODE=""
for arg in "$@"; do
    case "$arg" in
        --refresh) MODE="--refresh";;
        --waybar) MODE="--waybar";;
        --details) MODE="--details";;
        --print-cache) MODE="--print-cache";;
        --mode) MODE="--timer";;
        active|idle) [ "$MODE" = "--timer" ] && ARG_MODE="$arg";;
        -h|--help) sed -n '2,18p' "$0"; exit 0;;
    esac
done

ENABLED=$(flow_conf_get "$FLOW_AI_CONF" ENABLED); [ "$ENABLED" = "0" ] || ENABLED=1
AGENTS_RAW=$(flow_conf_get "$FLOW_AI_CONF" AGENTS)
[ -n "$AGENTS_RAW" ] || AGENTS_RAW="opencode,freebuff,claude,codex,kimi"
# shellcheck disable=SC2086
AGENTS=$(printf '%s' "$AGENTS_RAW" | tr ',' ' ')

agent_name() {
    case "$1" in
        opencode) printf 'OpenCode\n';;
        claude)   printf 'Claude Code\n';;
        codex)    printf 'Codex\n';;
        kimi)     printf 'Kimi Code\n';;
        freebuff) printf 'Freebuff\n';;
        *)        printf '%s\n' "$1";;
    esac
}

agent_proc() {
    case "$1" in
        opencode) printf 'opencode\n';;
        claude)   printf 'claude\n';;
        codex)    printf 'codex\n';;
        kimi)     printf 'kimi\n';;
        freebuff) printf 'freebuff\n';;
    esac
}

agent_dir() {
    local d
    case "$1" in
        opencode) for d in "$HOME/.local/share/opencode" "$HOME/.opencode"; do [ -d "$d" ] && { printf '%s\n' "$d"; return; }; done;;
        claude)   for d in "$HOME/.claude" "$HOME/.config/claude"; do [ -d "$d" ] && { printf '%s\n' "$d"; return; }; done;;
        codex)    for d in "$HOME/.codex" "$HOME/.config/codex";  do [ -d "$d" ] && { printf '%s\n' "$d"; return; }; done;;
        kimi)     for d in "$HOME/.kimi" "$HOME/.moonshot" "$HOME/.config/kimi"; do [ -d "$d" ] && { printf '%s\n' "$d"; return; }; done;;
        freebuff) for d in "$HOME/.freebuff" "$HOME/.config/freebuff" "$HOME/.local/share/freebuff"; do [ -d "$d" ] && { printf '%s\n' "$d"; return; }; done;;
    esac
}

recent() { # <dir> <seconds> -> 0 if something changed recently
    local dir="$1" secs="$2"
    [ -d "$dir" ] || return 1
    find "$dir" -newermt "-${secs} seconds" -print -quit 2>/dev/null | grep -q . && return 0
    return 1
}

agent_state() {
    local id="$1" pat dir
    pat=$(agent_proc "$id"); dir=$(agent_dir "$id")
    if pgrep -u "$USER" -f "$pat" >/dev/null 2>&1; then
        if recent "$dir" "$ACTIVE_T"; then printf 'active\n'; else printf 'idle\n'; fi
        return
    fi
    if recent "$dir" 120; then printf 'idle\n'; return; fi
    printf 'absent\n'
}

any_alive() {
    local id
    for id in $AGENTS; do
        pgrep -u "$USER" -f "$(agent_proc "$id")" >/dev/null 2>&1 && return 0
    done
    return 1
}

codex_tokens() {
    local f
    f=$(find "$HOME/.codex" -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    [ -n "$f" ] && [ -f "$f" ] || return 1
    python3 - "$f" <<'PY' 2>/dev/null
import re, sys
last = ""
for line in open(sys.argv[1], errors="ignore"):
    for m in re.finditer(r'"(?:total_tokens|totalTokens)"\s*:\s*(\d+)', line):
        last = m.group(1)
print(last)
PY
}

# ----------------------------------------------------- limit percentages --
# A percentage is either reported by the provider (a `percent` field in the
# usage payload) or derived from the agent's own local token counter compared
# with the 5-hour budget kept in ai.conf as LIMIT_<ID>. Best effort: an agent
# with neither source reports "—" instead of an invented number.
WINDOW_H=5

limit_for() { # <id> -> budget tokens (empty = no percentage)
    local key val
    key="LIMIT_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
    val=$(flow_conf_get "$FLOW_AI_CONF" "$key")
    case "$val" in ''|*[!0-9]*) return 1 ;; esac
    [ "$val" -gt 0 ] || return 1
    printf '%s\n' "$val"
}

opencode_tokens() {
    python3 - "$WINDOW_H" <<'PY'
import json, os, sqlite3, sys, time
p = os.path.expanduser("~/.local/share/opencode/opencode.db")
if not os.path.exists(p):
    sys.exit(1)
win = int(sys.argv[1]) * 3600
try:
    c = sqlite3.connect("file:%s?mode=ro" % p, uri=True)
    rows = c.execute("select data from message").fetchall()
except Exception:
    sys.exit(1)
now, tot = time.time(), 0
for (raw,) in rows:
    try:
        j = json.loads(raw)
    except Exception:
        continue
    ts = ((j.get("time") or {}).get("created") or 0) / 1000.0
    if not ts or now - ts > win:
        continue
    t = j.get("tokens")
    if not isinstance(t, dict):
        continue
    tot += sum(int(t.get(k) or 0) for k in ("input", "output", "reasoning"))
    cache = t.get("cache")
    if isinstance(cache, dict):
        tot += int(cache.get("read") or 0)
print(tot)
PY
}

claude_tokens() {
    python3 - "$WINDOW_H" <<'PY'
import glob, json, os, sys, time
root = os.path.expanduser("~/.claude")
if not os.path.isdir(root):
    sys.exit(1)
win = int(sys.argv[1]) * 3600
now, tot, seen = time.time(), 0, False
for path in glob.glob(root + "/**/*.jsonl", recursive=True):
    try:
        if now - os.path.getmtime(path) > win:
            continue
    except OSError:
        continue
    seen = True
    for line in open(path, errors="ignore"):
        try:
            j = json.loads(line)
        except Exception:
            continue
        u = (j.get("message") or {}).get("usage") or j.get("usage") or {}
        if isinstance(u, dict):
            tot += sum(int(u.get(k) or 0) for k in (
                "input_tokens", "output_tokens",
                "cache_read_input_tokens", "cache_creation_input_tokens"))
print(tot if seen else "")
if not seen:
    sys.exit(1)
PY
}

freebuff_tokens() {
    python3 - "$WINDOW_H" "$(agent_dir freebuff)" <<'PY'
import glob, os, re, sys, time
_, win_h, base = sys.argv[0:3]
if not base or not os.path.isdir(base):
    sys.exit(1)
win, now, tot, seen = int(win_h) * 3600, time.time(), 0, False
for path in glob.glob(base + "/**/*.json*", recursive=True):
    try:
        if now - os.path.getmtime(path) > win:
            continue
        raw = open(path, errors="ignore").read(2_000_000)
    except OSError:
        continue
    for m in re.finditer(r'"(?:total_tokens|tokens_used|used_tokens)"\s*:\s*(\d+)', raw):
        seen, tot = True, tot + int(m.group(1))
print(tot if seen else "")
if not seen:
    sys.exit(1)
PY
}

used_tokens() { # <id> -> tokens in the 5h window (empty when unknown)
    case "$1" in
        opencode) opencode_tokens ;;
        claude)   claude_tokens ;;
        codex)    codex_tokens ;;
        freebuff) freebuff_tokens ;;
        *)        return 1 ;;
    esac
}

# Optional API polling: only used when a usage endpoint is configured in
# ai.conf (ANTHROPIC_USAGE_URL / OPENAI_USAGE_URL). Hard 5s curl timeout.
api_usage() { # <url> <key> <header-name>
    local url="$1" key="$2" hdr="$3"
    [ -n "$url" ] && [ -n "$key" ] || return 1
    curl -sS --max-time 5 -H "$hdr: $key" -H 'Accept: application/json' "$url" 2>/dev/null \
        | python3 -c '
import json, re, sys
raw = sys.stdin.read()
nums = re.findall(r"(?:total_tokens|total_usage|total|usage)\D{0,12}(\d+)", raw)
print(nums[-1] if nums else "")
' 2>/dev/null
}

usage_for() { # prints "<usage>\t<source>"
    local id="$1" val="" key
    case "$id" in
        claude)
            key=$(flow_conf_get "$FLOW_AI_CONF" ANTHROPIC_API_KEY)
            if command -v ccusage >/dev/null 2>&1; then
                val=$(timeout 5 ccusage --json 2>/dev/null | python3 -c '
import json, sys
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k.lower() in ("totaltokens", "total_tokens"):
                return v
            r = walk(v)
            if r is not None:
                return r
    elif isinstance(o, list):
        for v in o:
            r = walk(v)
            if r is not None:
                return r
    return None
try:
    t = walk(json.load(sys.stdin))
    print(t if t is not None else "")
except Exception:
    print("")
' 2>/dev/null)
                [ -n "$val" ] && { printf '%s\tapi\n' "$val"; return; }
            fi
            val=$(api_usage "$(flow_conf_get "$FLOW_AI_CONF" ANTHROPIC_USAGE_URL)" "$key" "x-api-key")
            [ -n "$val" ] && { printf '%s\tapi\n' "$val"; return; }
            [ -n "$key" ] && { printf 'N/A\tapi\n'; return; }
            ;;
        codex)
            key=$(flow_conf_get "$FLOW_AI_CONF" OPENAI_API_KEY)
            if command -v codex-statusline >/dev/null 2>&1; then
                val=$(timeout 5 codex-statusline 2>/dev/null | grep -oE '[0-9]{3,}' | head -1)
                [ -n "$val" ] && { printf '%s\tlocal\n' "$val"; return; }
            fi
            val=$(codex_tokens)
            [ -n "$val" ] && { printf '%s\tlocal\n' "$val"; return; }
            val=$(api_usage "$(flow_conf_get "$FLOW_AI_CONF" OPENAI_USAGE_URL)" "$key" "Authorization")
            [ -n "$val" ] && { printf '%s\tapi\n' "$val"; return; }
            [ -n "$key" ] && { printf 'N/A\tapi\n'; return; }
            ;;
        opencode)
            printf 'local\tlocal\n'; return;;
        kimi)
            key=$(flow_conf_get "$FLOW_AI_CONF" MOONSHOT_API_KEY)
            [ -n "$key" ] && { printf 'local\tapi\n'; return; }
            printf 'local\tlocal\n'; return;;
    esac
    printf 'N/A\tnone\n'
}

write_cache() { # <enabled> <probe-file>
    python3 - "$1" "$2" "$FLOW_AI_CACHE" <<'PY'
import json, os, sys, time
enabled, src, dst = int(sys.argv[1]), sys.argv[2], sys.argv[3]
agents = []
try:
    for line in open(src, encoding="utf-8"):
        p = line.rstrip("\n").split("\t")
        if len(p) < 5:
            continue
        def num(i):
            v = p[i].strip() if len(p) > i else ""
            return int(v) if v.isdigit() else None
        agents.append({
            "id": p[0], "name": p[1], "state": p[2], "usage": p[3], "source": p[4],
            "percent": num(5), "used": num(6), "limit": num(7),
        })
except FileNotFoundError:
    pass
data = {"ts": int(time.time()), "enabled": enabled, "agents": agents}
tmp = dst + ".tmp"
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=1)
os.replace(tmp, dst)
PY
}

do_refresh() {
    flow_lock || return 1
    local tmp id st us src
    if [ "$ENABLED" != "1" ]; then
        tmp=$(mktemp); : >"$tmp"; write_cache 0 "$tmp"; rm -f "$tmp"
        return 0
    fi
    tmp=$(mktemp) || return 1
    : >"$tmp"
    for id in $AGENTS; do
        st=$(agent_state "$id")
        IFS=$'\t' read -r us src <<<"$(usage_for "$id")"
        [ -n "$us" ] || us="N/A"
        [ -n "$src" ] || src="none"
        pct=""; used=""; lim=""
        if [ "$st" != "absent" ]; then
            used=$(used_tokens "$id" 2>/dev/null) || used=""
            lim=$(limit_for "$id" 2>/dev/null) || lim=""
            if [ -n "$used" ] && [ -n "$lim" ]; then
                pct=$((used * 100 / lim))
                [ "$pct" -gt 100 ] && pct=100
            fi
        fi
        # an agent that is not even installed reports no usage, not a fake 0
        if [ "$st" = "absent" ]; then us="N/A"; src="none"; pct=""; used=""; lim=""; fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$id" "$(agent_name "$id")" "$st" "$us" "$src" "$pct" "$used" "$lim" >>"$tmp"
    done
    write_cache 1 "$tmp"
    rm -f "$tmp"
    return 0
}

cache_age() {
    [ -f "$FLOW_AI_CACHE" ] || { printf '999999\n'; return; }
    python3 - "$FLOW_AI_CACHE" <<'PY' 2>/dev/null
import json, sys, time
try:
    print(int(time.time()) - int(json.load(open(sys.argv[1])).get("ts", 0)))
except Exception:
    print(999999)
PY
}

# --------------------------------------------------------------- modes -----
case "$MODE" in
    --refresh)
        do_refresh
        exit $?
        ;;
    --timer)
        [ "$ENABLED" = "1" ] || exit 0
        age=$(cache_age)
        if [ "$ARG_MODE" = "active" ]; then
            any_alive || exit 0
            [ "$age" -lt 25 ] && exit 0
        else
            if any_alive; then
                [ "$age" -lt "$IDLE_GATE" ] && exit 0
            else
                [ "$age" -lt "$ALL_GATE" ] && exit 0
            fi
        fi
        do_refresh
        exit $?
        ;;
    --print-cache)
        cat "$FLOW_AI_CACHE" 2>/dev/null || exit 1
        ;;
    --waybar)
        age=$(cache_age)
        [ "$age" -gt 90 ] && do_refresh >/dev/null 2>&1
        python3 - "$FLOW_AI_CACHE" "$(_m ai_disabled)" "$(_m ai_na)" "$(_m ai_active)" \
                 "$(_m ai_idle)" "$(_m ai_absent)" <<'PY'
import json, sys
path, dis_txt, na, act, idl, absn = sys.argv[1:7]
try:
    d = json.load(open(path, encoding="utf-8"))
except Exception:
    print(json.dumps({"text": na, "tooltip": na, "class": "ai-off"}))
    sys.exit(0)
if not d.get("enabled", 1):
    print(json.dumps({"text": dis_txt, "tooltip": dis_txt, "class": "ai-off"}, ensure_ascii=False))
    sys.exit(0)
labels = {"active": act, "idle": idl, "absent": absn}
agents = d.get("agents", [])
n_active = sum(1 for a in agents if a.get("state") == "active")
if not agents:
    print(json.dumps({"text": na, "tooltip": "no agents", "class": "ai-off"}))
    sys.exit(0)
def amount(a, fallback):
    p = a.get("percent")
    return "%d%%" % p if isinstance(p, int) else fallback


lines = []
for a in agents:
    lines.append("%s — %s (%s)" % (a.get("name", a.get("id")),
                                   labels.get(a.get("state"), a.get("state")),
                                   amount(a, a.get("usage", na))))
text = "󰚩 %d/%d" % (n_active, len(agents))
cls = "ai-active" if n_active else "ai-idle"
print(json.dumps({"text": text, "tooltip": "\n".join(lines), "class": cls}, ensure_ascii=False))
PY
        ;;
    --details)
        age=$(cache_age)
        [ "$age" -gt 90 ] && do_refresh >/dev/null 2>&1
        python3 - "$FLOW_AI_CACHE" "$(_m ai_disabled)" "$(_m ai_active)" "$(_m ai_idle)" \
                 "$(_m ai_absent)" <<'PY'
import json, sys, time
path, dis_txt, act, idl, absn = sys.argv[1:6]
try:
    d = json.load(open(path, encoding="utf-8"))
except Exception:
    print(dis_txt)
    sys.exit(0)
out = []
if not d.get("enabled", 1):
    print(dis_txt)
    sys.exit(0)
labels = {"active": act, "idle": idl, "absent": absn}
for a in d.get("agents", []):
    p = a.get("percent")
    pct = "%d%%" % p if isinstance(p, int) else "—"
    if isinstance(a.get("used"), int) and isinstance(a.get("limit"), int):
        pct = "%s (%s/%s)" % (pct, a["used"], a["limit"])
    out.append("%-12s %-9s %-24s %s" % (a.get("name", ""), labels.get(a.get("state"), ""),
                                         pct, a.get("source", "")))
ts = d.get("ts", 0)
if ts:
    out.append("")
    out.append("%s: %s" % ("updated", time.strftime("%H:%M:%S", time.localtime(ts))))
print("\n".join(out))
PY
        ;;
esac
exit 0
