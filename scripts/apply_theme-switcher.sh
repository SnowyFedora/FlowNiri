#!/usr/bin/env bash
# ============================================================
#  FlowNiri — light/dark mode for GTK3, GTK4 and Qt
#
#  GTK applications (Zenity, Nautilus, Firefox, …) always use the
#  standard Adwaita theme now. Their look follows the GNOME
#  color-scheme, never the FlowNiri palette:
#
#      light  ->  color-scheme prefer-light, gtk-theme Adwaita
#      dark   ->  color-scheme prefer-dark,  gtk-theme Adwaita-dark
#
#  The custom palette is applied only to Niri, Waybar and Fuzzel,
#  because those have their own configs (scripts/theme-switcher.sh).
#  Recolouring libadwaita globally with ~/.config/gtk-4.0/gtk.css is
#  what used to break Nautilus (broken margins, black-on-black text)
#  and Firefox, so that file is removed when it is ours.
#
#  Usage:
#    apply_theme-switcher.sh [--mode light|dark] [--restart-qt] [--quiet] <theme-id>
#    apply_theme-switcher.sh            # re-applies ~/.config/FlowNiri/theme.name
#
#  Light/dark detection order:
#    1. MODE=light|dark inside the theme file
#    2. keywords in the theme id (light/white/светл…, dark/темн…)
#    3. luminance of BG
# ============================================================
set -o pipefail

FLOW_DIR="$HOME/.config/FlowNiri"
THEMES_DIR="$HOME/.config/themes"
GTK3_DIR="$HOME/.config/gtk-3.0"
GTK4_DIR="$HOME/.config/gtk-4.0"
GTK_THEMES_DIR="$HOME/.local/share/themes"
ENVD_DIR="$HOME/.config/environment.d"
QT_ENV="$FLOW_DIR/qt.env"
THEME_NAME_FILE="$FLOW_DIR/theme.name"

THEME_ID=""
MODE_OVERRIDE=""
RESTART_QT=0
QUIET=0

usage() {
    cat <<'EOF'
FlowNiri — light/dark mode for GTK3, GTK4 and Qt

Usage: apply_theme-switcher.sh [options] [theme-id]

  theme-id           ~/.config/themes/<theme-id>.theme
                     (default: the id stored in ~/.config/FlowNiri/theme.name)

Options:
  --mode light|dark  force the mode instead of auto-detection
  --restart-qt       restart running Qt apps (CopyQ, Telegram) afterwards
  -q, --quiet        do not print the summary
  -h, --help         show this help

GTK apps are switched to standard Adwaita (light) or Adwaita-dark (dark)
through org.gnome.desktop.interface color-scheme. The palette from the theme
file is only used by Niri, Waybar and Fuzzel.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --mode)
            [ "$#" -ge 2 ] || { echo "--mode needs light|dark" >&2; exit 2; }
            MODE_OVERRIDE="$2"
            shift 2
            ;;
        --mode=*) MODE_OVERRIDE="${1#*=}"; shift ;;
        --restart-qt) RESTART_QT=1; shift ;;
        -q|--quiet) QUIET=1; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        *) THEME_ID="$1"; shift ;;
    esac
done

if [ -z "$THEME_ID" ] && [ -f "$THEME_NAME_FILE" ]; then
    THEME_ID=$(head -n 1 "$THEME_NAME_FILE" 2>/dev/null | tr -d '\r' | sed -e 's/[[:space:]]*$//')
fi

if [ -z "$THEME_ID" ]; then
    echo "No theme id given and $THEME_NAME_FILE is empty." >&2
    exit 2
fi

# Allow non-ASCII ids (e.g. "Светлая") but never path traversal.
case "$THEME_ID" in
    */*|*..*|.*) echo "Invalid theme id: $THEME_ID" >&2; exit 2 ;;
esac

THEME_SRC="$THEMES_DIR/$THEME_ID.theme"
if [ ! -f "$THEME_SRC" ]; then
    echo "Theme not found: $THEME_SRC" >&2
    exit 2
fi

# ------------------------------------------------------------ helpers ----
# Reads KEY=value from the theme file, strips CR and surrounding quotes.
field() {
    sed -n "s/^$1=//p" "$THEME_SRC" 2>/dev/null \
        | head -n 1 \
        | tr -d '\r' \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
              -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

# Perceived brightness 0..255 of a bare or #rrggbb colour.
luminance() {
    local hex="${1#\#}"
    local r g b
    if ! [[ "$hex" =~ ^[0-9a-fA-F]{6}$ ]]; then
        printf '0'
        return
    fi
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))
    printf '%s' $(((r * 299 + g * 587 + b * 114) / 1000))
}

ini_get() { # <file> <key>
    sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1" 2>/dev/null \
        | head -n 1 | tr -d '\r'
}

notify() { # <summary> <body>
    [ "$QUIET" -eq 1 ] && return 0
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a FlowNiri -i preferences-desktop-theme "$1" "$2" >/dev/null 2>&1 || true
    fi
}

# ---------------------------------------------------------------- mode ---
detect_mode() {
    local raw lum bg
    raw=$(field MODE | tr 'A-Z' 'a-z')
    case "$raw" in
        light|light-mode|lightmode|white|day|светлая|светлый|светло) echo light; return ;;
        dark|dark-mode|darkmode|black|night|темная|тёмная|темный|тёмный|темно|тёмно) echo dark; return ;;
    esac

    case "$(printf '%s' "$THEME_ID" | tr 'A-Z' 'a-z')" in
        *light*|*white*|*day*) echo light; return ;;
        *dark*|*night*|*black*|*midnight*) echo dark; return ;;
    esac

    case "$THEME_ID" in
        *[Сс]ветл*|*[Бб]ел*) echo light; return ;;
        *[Тт]емн*|*[Тт]ёмн*|*[Чч]ерн*|*[Чч]ёрн*) echo dark; return ;;
    esac

    bg=$(field BG)
    lum=$(luminance "$bg")
    if [ "$lum" -ge 128 ]; then echo light; else echo dark; fi
}

case "${MODE_OVERRIDE,,}" in
    light) MODE="light" ;;
    dark) MODE="dark" ;;
    "") MODE=$(detect_mode) ;;
    *) echo "Invalid --mode value: $MODE_OVERRIDE (use light|dark)" >&2; exit 2 ;;
esac

# ---------------------------------------------------------- Adwaita -----
# Adwaita ships with GTK; the dark variant is selected by color-scheme.
# gtk-theme-name only matters for GTK3 apps (Firefox) and older dialogs.
if [ "$MODE" = "light" ]; then
    SCHEME="prefer-light"
    PREFER_DARK=0
    QT_STYLE="Adwaita"
    GTK_THEME="Adwaita"
else
    SCHEME="prefer-dark"
    PREFER_DARK=1
    QT_STYLE="Adwaita-Dark"
    GTK_THEME="Adwaita-dark"
    # Fall back to plain Adwaita if the dark theme is not installed:
    # prefer-dark still gives libadwaita apps the dark palette.
    if [ ! -d "/usr/share/themes/Adwaita-dark" ] \
        && [ ! -d "$GTK_THEMES_DIR/Adwaita-dark" ]; then
        GTK_THEME="Adwaita"
    fi
fi

# ------------------------------------------------------ existing gtk ini -
mkdir -p "$GTK3_DIR" "$GTK4_DIR"

CURSOR_NAME=$(ini_get "$GTK3_DIR/settings.ini" gtk-cursor-theme-name)
CURSOR_NAME=${CURSOR_NAME:-Bibata-Modern-Ice}
CURSOR_SIZE=$(ini_get "$GTK3_DIR/settings.ini" gtk-cursor-theme-size)
CURSOR_SIZE=${CURSOR_SIZE:-24}
ICON_NAME=$(ini_get "$GTK3_DIR/settings.ini" gtk-icon-theme-name)
ICON_NAME=${ICON_NAME:-Adwaita}
FONT_NAME=$(ini_get "$GTK3_DIR/settings.ini" gtk-font-name)
FONT_NAME=${FONT_NAME:-"Sans 10"}

write_gtk_ini() { # <dir>
    mkdir -p "$1" || return 1
    cat >"$1/settings.ini" <<EOF
# Generated by FlowNiri — apply_theme-switcher.sh
# Standard Adwaita only: the FlowNiri palette is not applied to GTK apps.
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=$ICON_NAME
gtk-font-name=$FONT_NAME
gtk-cursor-theme-name=$CURSOR_NAME
gtk-cursor-theme-size=$CURSOR_SIZE
gtk-application-prefer-dark-theme=$PREFER_DARK
gtk-enable-animations=true
EOF
}

write_gtk_ini "$GTK3_DIR" || { echo "Cannot write $GTK3_DIR/settings.ini" >&2; exit 1; }
write_gtk_ini "$GTK4_DIR" || { echo "Cannot write $GTK4_DIR/settings.ini" >&2; exit 1; }

# ------------------------------------------- remove recoloured GTK CSS ---
# Older FlowNiri versions wrote full palette overrides into
# ~/.config/gtk-3.0/gtk.css and ~/.config/gtk-4.0/gtk.css. Those files make
# Nautilus, Zenity and Firefox unusable (black on black, broken margins).
# Only files carrying our header are removed; a user's own gtk.css stays.
remove_generated_css() {
    local file
    for file in "$GTK3_DIR/gtk.css" "$GTK4_DIR/gtk.css"; do
        [ -f "$file" ] || continue
        if head -n 3 "$file" 2>/dev/null | grep -q 'Generated by FlowNiri'; then
            rm -f "$file" && echo "removed generated $file"
        fi
    done
    # Legacy generated Adwaita copies (full recoloured theme directories).
    rm -rf "$GTK_THEMES_DIR"/FlowNiri-* 2>/dev/null
}

remove_generated_css

# ---------------------------------------------------------- gsettings ----
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme "$SCHEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
fi

# ----------------------------------------------------------------- Qt ----
# export only affects this script; the files make it stick for new apps.
mkdir -p "$ENVD_DIR"
cat >"$QT_ENV" <<EOF
# FlowNiri — Qt follows GTK ($THEME_ID / $MODE)
QT_QPA_PLATFORMTHEME=gtk3
QT_STYLE_OVERRIDE=$QT_STYLE
EOF

cat >"$ENVD_DIR/90-flowniri-qt.conf" <<EOF
# FlowNiri — Qt follows GTK ($THEME_ID / $MODE)
QT_QPA_PLATFORMTHEME=gtk3
QT_STYLE_OVERRIDE=$QT_STYLE
EOF

export QT_QPA_PLATFORMTHEME=gtk3
export QT_STYLE_OVERRIDE="$QT_STYLE"

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd \
        QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE >/dev/null 2>&1 || true
fi
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment \
        QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE >/dev/null 2>&1 || true
fi

# ------------------------------------------------- running Qt apps -------
QT_RUNNING=()
if pgrep -x copyq >/dev/null 2>&1; then
    QT_RUNNING+=("CopyQ")
fi
if pgrep -x telegram-desktop >/dev/null 2>&1 \
    || pgrep -x Telegram >/dev/null 2>&1 \
    || pgrep -x TelegramDesktop >/dev/null 2>&1; then
    QT_RUNNING+=("Telegram")
fi

restart_qt_apps() {
    local app
    for app in "${QT_RUNNING[@]}"; do
        case "$app" in
            CopyQ)
                pkill -x copyq >/dev/null 2>&1
                sleep 0.4
                setsid copyq >/dev/null 2>&1 &
                ;;
            Telegram)
                pkill -x telegram-desktop >/dev/null 2>&1
                pkill -x Telegram >/dev/null 2>&1
                pkill -x TelegramDesktop >/dev/null 2>&1
                sleep 1
                if command -v telegram-desktop >/dev/null 2>&1; then
                    setsid telegram-desktop >/dev/null 2>&1 &
                elif command -v flatpak >/dev/null 2>&1 \
                    && flatpak info org.telegram.desktop >/dev/null 2>&1; then
                    setsid flatpak run org.telegram.desktop >/dev/null 2>&1 &
                fi
                ;;
        esac
    done
}

if [ "${#QT_RUNNING[@]}" -gt 0 ] && [ "$RESTART_QT" -eq 1 ]; then
    restart_qt_apps
fi

# ------------------------------------------------------------- state -----
printf '%s\n' "$THEME_ID" >"$THEME_NAME_FILE"

# ------------------------------------------------------------- output ----
printf 'THEME=%s\n' "$THEME_ID"
printf 'MODE=%s\n' "$MODE"
printf 'COLOR_SCHEME=%s\n' "$SCHEME"
printf 'GTK_THEME=%s\n' "$GTK_THEME"
printf 'QT_QPA_PLATFORMTHEME=gtk3\n'
printf 'QT_STYLE_OVERRIDE=%s\n' "$QT_STYLE"

if [ "${#QT_RUNNING[@]}" -gt 0 ]; then
    JOINED=$(printf '%s, ' "${QT_RUNNING[@]}")
    JOINED=${JOINED%, }
    printf 'QT_RESTART=%s\n' "$JOINED"
    if [ "$RESTART_QT" -eq 0 ]; then
        notify "FlowNiri" "Режим применён. Перезапустите Qt-приложения: $JOINED"
    fi
fi

if [ "$QUIET" -eq 0 ]; then
    echo "Theme '$THEME_ID' applied ($MODE). GTK=$GTK_THEME ($SCHEME) Qt=$QT_STYLE"
fi
exit 0
