#!/usr/bin/env bash
# ============================================================
#  FlowNiri — hotkey overlay (Mod+/)
#  Parses the binds block of niri/config.kdl and shows the list in
#  fuzzel, using the same config/theme as the app launcher.
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

CONFIG_KDL="$FLOW_CONFIG/niri/config.kdl"
LANG_ID="$(flow_lang)"
DUMP=0
[ "${1:-}" = "--dump" ] && DUMP=1

LIST=$(python3 - "$CONFIG_KDL" "$LANG_ID" <<'PY'
import re, sys

path, lang = sys.argv[1], sys.argv[2]

ACTIONS = {
    "close-window":        ("Закрыть окно", "Close window"),
    "quit":                ("Выход из Niri", "Quit Niri"),
    "toggle-overview":     ("Обзор", "Overview"),
    "fullscreen-window":   ("Полный экран", "Fullscreen"),
    "toggle-windowed-fullscreen": ("Полноэкранный режим", "Windowed fullscreen"),
    "focus-column-left":   ("Фокус влево", "Focus left"),
    "focus-column-right":  ("Фокус вправо", "Focus right"),
    "focus-window-up":     ("Фокус вверх", "Focus up"),
    "focus-window-down":   ("Фокус вниз", "Focus down"),
    "move-column-left":    ("Переместить влево", "Move left"),
    "move-column-right":   ("Переместить вправо", "Move right"),
    "move-window-up":      ("Переместить вверх", "Move up"),
    "move-window-down":    ("Переместить вниз", "Move down"),
    "switch-preset-column-width": ("Ширина окна", "Column width"),
    "switch-preset-column-width-back": ("Ширина окна (назад)", "Column width back"),
    "switch-preset-window-height": ("Высота окна", "Window height"),
    "power-off-monitors":  ("Выключить мониторы", "Power off monitors"),
    "switch-layout":       ("Сменить раскладку", "Switch layout"),
    "screenshot":          ("Скриншот", "Screenshot"),
    "screenshot-screen":   ("Скриншот экрана", "Screen screenshot"),
    "screenshot-window":   ("Скриншот окна", "Window screenshot"),
    "show-hotkey-overlay": ("Подсказка клавиш", "Hotkey help"),
    "toggle-keyboard-shortcuts-inhibit": ("Блокировка горячих клавиш", "Inhibit hotkeys"),
    "load-config-file":    ("Перезагрузить конфиг", "Reload config"),
}

SPAWNS = [
    ("alacritty",          "Терминал", "Terminal"),
    ("fuzzel",             "Лаунчер", "Launcher"),
    ("nautilus",           "Файловый менеджер", "File manager"),
    ("gtklock",            "Блокировка экрана", "Lock screen"),
    ("flowniri-menu.sh",   "Меню FlowNiri", "FlowNiri menu"),
    ("hotkeys.sh",         "Горячие клавиши", "Hotkeys"),
    ("ai-launcher.sh",     "ИИ-монитор", "AI monitor"),
    ("power_menu.sh",      "Меню питания", "Power menu"),
    ("power-menu.sh",      "Профиль питания", "Power profile"),
    ("Wallpaper-settings.sh", "Сменить обои", "Change wallpaper"),
    ("screenshot.sh",      "Скриншот в буфер", "Screenshot to clipboard"),
    ("record.sh",          "Запись экрана", "Screen recording"),
    ("osd.sh",             "Звук / яркость", "Volume / brightness"),
    ("slurp",              "Скриншот области", "Region screenshot"),
]

RU_KEYS = {
    "audio": ("Звук", "Volume"), "bright": ("Яркость", "Brightness"),
    "mic": ("Микрофон", "Microphone"), "media": ("Медиа", "Media"),
    "overview": ("Обзор", "Overview"), "print": ("Печать/скриншот", "Print"),
}

# Most specific matches first: volume/mute/brightness share one script.
SPECIFIC = [
    ("mic-mute", "Микрофон", "Microphone"),
    ("volume",   "Звук", "Volume"),
    ("bright",   "Яркость", "Brightness"),
    ("mute",     "Без звука", "Mute"),
]

def describe(action, title):
    low = action.lower()
    for needle, ru, en in SPECIFIC:
        if needle in low:
            return ru if lang == "ru" else en
    for needle, ru, en in SPAWNS:
        if needle.lower() in low:
            return ru if lang == "ru" else en
    for key, val in ACTIONS.items():
        if key in low:
            return val[0] if lang == "ru" else val[1]
    for key, val in RU_KEYS.items():
        if key in low:
            return val[0] if lang == "ru" else val[1]
    if title:
        return title
    clean = action.strip().strip("{}").strip().strip(";").strip()
    clean = re.sub(r"\s+", " ", clean)
    return (clean[:48] + "…") if len(clean) > 49 else clean

out, in_binds = [], False
for raw in open(path, encoding="utf-8"):
    s = raw.strip()
    if not in_binds:
        if re.match(r"^binds\s*\{", s):
            in_binds = True
        continue
    if not s or s.startswith("//"):
        continue
    if s == "}":
        break
    m = re.match(r'^([A-Za-z0-9_+]+)\s*(.*?)\{(.*)\}\s*$', s)
    if not m:
        continue
    key, attrs, action = m.group(1), m.group(2), m.group(3)
    if "hotkey-overlay-title=null" in attrs:
        continue
    t = re.search(r'hotkey-overlay-title="([^"]*)"', attrs)
    out.append("%s|%s" % (key, describe(action, t.group(1) if t else "")))

print("\n".join(out))
PY
)

if [ -z "$LIST" ]; then
    flow_notify "$(_m hk_title)" "$(_m hk_none)" "dialog-error"
    exit 1
fi

DISPLAY_LIST=$(printf '%s\n' "$LIST" | awk -F'|' '{printf "%-22s %s\n", $1, $2}')

if [ "$DUMP" -eq 1 ]; then
    printf '%s\n' "$DISPLAY_LIST"
    exit 0
fi

printf '%s\n' "$DISPLAY_LIST" | fuzzel --dmenu \
    --prompt="$(_m hk_title)  " \
    --width=46 --lines=26 \
    --no-sort --counter --placeholder="" >/dev/null 2>&1
