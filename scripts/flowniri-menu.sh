#!/usr/bin/env bash
# ============================================================
#  FlowNiri — unified control menu
#  Every dialog uses the same zenity wrapper + generated GTK theme,
#  so all menus look identical and follow the active palette.
#  Cancel (exit 1) always returns to the main menu unchanged.
# ============================================================
set -o pipefail

# shellcheck source=/dev/null
. "$HOME/.config/FlowNiri/lib/common.sh"
flow_i18n_load

flow_has_display || { echo "FlowNiri menu needs a graphical session (WAYLAND_DISPLAY/DISPLAY)." >&2; exit 1; }
flow_require zenity "$(_m err_no_zenity)" || exit 1
flow_require niri   "$(_m err_no_niri)"

CONFIG_KDL="$FLOW_CONFIG/niri/config.kdl"
WAYBAR_JSON="$FLOW_CONFIG/waybar/config.jsonc"
IDLE_SH="$FLOW_SCRIPTS/idle.sh"

# ------------------------------------------------------------ helpers ------
niri_radius() {
    grep -oE '^[[:space:]]*geometry-corner-radius[[:space:]]+[0-9]+' "$CONFIG_KDL" 2>/dev/null \
        | tail -1 | grep -oE '[0-9]+$'
}

idle_seconds() { # <lock|suspend>
    local pat='gtklock' cur
    [ "$1" = "suspend" ] && pat='suspend'
    cur=$(grep -E "timeout[[:space:]]+[0-9]+.*$pat" "$IDLE_SH" 2>/dev/null | head -1 | grep -oE 'timeout[[:space:]]+[0-9]+' | grep -oE '[0-9]+')
    printf '%s\n' "${cur:-0}"
}

restart_idle() {
    pkill -x swayidle 2>/dev/null
    sleep 0.2
    setsid "$IDLE_SH" >/dev/null 2>&1 &
}

# Waybar modules-right manipulation. Delegated to the CLI: it keeps the
# canonical order, so a module switched back on returns to its old slot.
waybar_tool() { # --list | --toggle <module>
    case "$1" in
        --list)   "$FLOW_SCRIPTS/flowniri-cli.sh" waybar-present ;;
        --toggle) "$FLOW_SCRIPTS/flowniri-cli.sh" waybar-toggle "$2" >/dev/null ;;
        *)        return 2 ;;
    esac
}

install_desktop_entries() { # from a release payload / install tree
    local src="$1" f dst="$HOME/.local/share/applications"
    [ -d "$src" ] || return 0
    mkdir -p "$dst"
    for f in "$src"/*.desktop; do
        [ -f "$f" ] || continue
        cp -f "$f" "$dst/"
    done
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$dst" >/dev/null 2>&1
}

# ------------------------------------------------------------- items -------
do_wallpaper() {
    local f esc bak
    f=$(dlg_file "$(_m wallpaper_title)" "$(_m wallpaper_filter)" "*.png *.jpg *.jpeg *.webp")
    [ -n "$f" ] || return 0
    esc=${f//\\/\\\\}; esc=${esc//&/\\&}; esc=${esc//|/\\|}
    bak=$(flow_snapshot)
    sed -i -E "s|^[[:space:]]*spawn-at-startup \"swaybg\".*|    spawn-at-startup \"swaybg\" \"-m\" \"fill\" \"-i\" \"$esc\"|" "$CONFIG_KDL"
    if ! flow_apply_niri "$bak" "wallpaper"; then
        return 1
    fi
    pkill -x swaybg 2>/dev/null
    sleep 0.2
    niri msg action spawn -- swaybg -m fill -i "$f" >/dev/null 2>&1
    flow_notify "$(_m app_title)" "$(_m wallpaper_done)" "preferences-desktop-wallpaper"
}

do_lock() {
    local lock_min sleep_min lock_s sleep_s out
    lock_min=$(idle_seconds lock);   lock_min=$((lock_min / 60)); [ "$lock_min" -gt 0 ] || lock_min=5
    sleep_min=$(idle_seconds suspend); sleep_min=$((sleep_min / 60)); [ "$sleep_min" -gt 0 ] || sleep_min=15

    out=$(dlg_forms --title="$(_m lock_title)" --text="$(_m lock_text)" \
        --add-entry="$(_m lock_lock)" \
        --add-entry="$(_m lock_sleep)")
    [ $? -eq 0 ] || return 0
    [ -n "$out" ] || return 0
    local a b
    a="$(printf '%s' "$out" | cut -d'|' -f1)"
    b="$(printf '%s' "$out" | cut -d'|' -f2)"
    a="${a:-$lock_min}"; b="${b:-$sleep_min}"
    case "$a$b" in (*[!0-9]*|"") dlg_error "$(_m err_title)" "$(_m lock_bad)"; return 1;; esac

    lock_s=$((a * 60)); sleep_s=$((b * 60))
    cat >"$IDLE_SH" <<EOF
#!/bin/bash
# FlowNiri idle timers — rewritten by flowniri-menu.sh
swayidle -w \\
  timeout $lock_s 'gtklock' \\
  timeout $sleep_s 'systemctl suspend' \\
  before-sleep 'gtklock'
EOF
    chmod +x "$IDLE_SH"
    restart_idle
    dlg_info "$(_m lock_title)" "$(printf "$(_m lock_done)" "$a" "$b")"
}

do_defaults() {
    local browser fm editor out
    browser=$(xdg-settings get default-web-browser 2>/dev/null); browser=${browser%.desktop}
    [ -n "$browser" ] || browser=firefox
    fm="org.gnome.Nautilus"
    editor=$(xdg-mime query default text/plain 2>/dev/null); editor=${editor%.desktop}
    [ -n "$editor" ] || editor=micro

    out=$(dlg_forms --title="$(_m defaults_title)" --text="$(_m defaults_text)" \
        --add-entry="$(_m defaults_browser)" --add-entry="$(_m defaults_fm)" --add-entry="$(_m defaults_editor)" \
        --separator='|')
    [ $? -eq 0 ] && [ -n "$out" ] || return 0

    browser=$(printf '%s' "$out" | cut -d'|' -f1)
    fm=$(printf '%s' "$out" | cut -d'|' -f2)
    editor=$(printf '%s' "$out" | cut -d'|' -f3)

    [ -n "$browser" ] && xdg-settings set default-web-browser "${browser%.desktop}.desktop" 2>/dev/null
    [ -n "$fm" ] && { xdg-mime default "${fm%.desktop}.desktop" inode/directory 2>/dev/null
                      xdg-settings set default-file-manager "${fm%.desktop}.desktop" 2>/dev/null; }
    [ -n "$editor" ] && xdg-mime default "${editor%.desktop}.desktop" text/plain 2>/dev/null
    dlg_info "$(_m defaults_title)" "$(_m defaults_done)"
}

do_theme() {
    local ids=() rows=() id cur
    cur="$(flow_theme_id)"
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        ids+=("$id")
        if [ "$id" = "$cur" ]; then rows+=("● $(flow_theme_label "$id")|$id")
        else rows+=("  $(flow_theme_label "$id")|$id"); fi
    done <<<"$(flow_theme_ids)"
    [ "${#rows[@]}" -gt 0 ] || { dlg_error "$(_m err_title)" "$(_m theme_missing)"; return 1; }

    id=$(dlg_list "$(_m theme_title)" "$(_m theme_text)" "${rows[@]}") || return 0
    [ -n "$id" ] || return 0
    if "$FLOW_SCRIPTS/theme-switcher.sh" --silent "$id"; then
        dlg_info "$(_m theme_title)" "$(printf "$(_m theme_done)" "$(flow_theme_label "$id")")"$'\n'"$(_m theme_hint)"
    fi
}

do_waybar() {
    local modules=() rows=() current=() mod on state
    local -a known=("niri/language" "network" "pulseaudio" "cpu" "memory" "battery" "clock" "custom/ai-status" "tray")

    current_text=$(waybar_tool --list) || { dlg_error "$(_m err_title)" "$WAYBAR_JSON"; return 1; }
    while IFS= read -r mod; do
        [ -n "$mod" ] && current+=("$mod")
    done <<<"$current_text"

    while true; do
        rows=()
        for mod in "${known[@]}"; do
            state="✗"
            if printf '%s\n' "${current[@]}" | grep -qx "$mod"; then state="✓"; fi
            rows+=("$state  $mod|$mod")
        done
        rows+=("← $(_m btn_cancel)|__back__")

        mod=$(dlg_list "$(_m waybar_title)" "$(_m waybar_text)" "${rows[@]}") || return 0
        [ "$mod" = "__back__" ] && return 0
        [ -n "$mod" ] || return 0

        waybar_tool --toggle "$mod" || { dlg_error "$(_m err_title)" "$WAYBAR_JSON"; return 1; }
        current_text=$(waybar_tool --list)
        current=()
        while IFS= read -r mod; do
            [ -n "$mod" ] && current+=("$mod")
        done <<<"$current_text"
        if [ "$mod" = "custom/ai-status" ]; then
            flow_notify "$(_m app_title)" "$(_m waybar_need_module)"
        fi
        flow_restart_waybar
    done
}

ai_agents_list() {
    local id out=()
    for id in opencode freebuff claude codex kimi; do
        if printf '%s\n' "$(flow_conf_get "$FLOW_AI_CONF" AGENTS | tr ',' ' ')" | grep -qw "$id"; then
            out+=("✓  $id|$id")
        else
            out+=("✗  $id|$id")
        fi
    done
    printf '%s\n' "${out[@]}"
}

do_ai() {
    local enabled rows=() pick keys out a b c
    while true; do
        enabled=$(flow_conf_get "$FLOW_AI_CONF" ENABLED)
        [ "$enabled" = "0" ] || enabled=1
        if [ "$enabled" = "1" ]; then
            rows=("$(printf "$(_m ai_monitoring)" "$(_m ai_on)")|toggle" "$(_m ai_agents)|agents" "$(_m ai_keys)|keys" "$(_m ai_refresh)|refresh" "← $(_m btn_cancel)|__back__")
        else
            rows=("$(printf "$(_m ai_monitoring)" "$(_m ai_off)")|toggle" "$(_m ai_agents)|agents" "$(_m ai_keys)|keys" "$(_m ai_refresh)|refresh" "← $(_m btn_cancel)|__back__")
        fi

        pick=$(dlg_list "$(_m ai_title)" "$(_m ai_text)" "${rows[@]}") || return 0
        case "$pick" in
            __back__|"") return 0;;
            toggle)
                if [ "$enabled" = "1" ]; then flow_conf_set "$FLOW_AI_CONF" ENABLED 0
                else flow_conf_set "$FLOW_AI_CONF" ENABLED 1; fi
                chmod 600 "$FLOW_AI_CONF" 2>/dev/null
                flow_restart_waybar
                ;;
            agents)
                while true; do
                    local arows=() ag
                    while IFS= read -r ag; do arows+=("$ag"); done <<<"$(ai_agents_list)"
                    arows+=("← $(_m btn_cancel)|__back__")
                    ag=$(dlg_list "$(_m ai_title)" "$(_m ai_text)" "${arows[@]}") || break
                    [ "$ag" = "__back__" ] && break
                    [ -n "$ag" ] || break
                    local cur list new=""
                    cur=$(flow_conf_get "$FLOW_AI_CONF" AGENTS)
                    for id in ${cur//,/ }; do [ "$id" = "$ag" ] || new="$new${new:+,}$id"; done
                    if ! printf '%s\n' "${cur//,/ }" | grep -qw "$ag"; then
                        new="${cur:+$cur,}$ag"
                    fi
                    flow_conf_set "$FLOW_AI_CONF" AGENTS "$new"
                done
                ;;
            keys)
                out=$(dlg_forms --title="$(_m ai_keys)" --text="$(_m ai_hint)" \
                    --add-password="$(_m ai_key_anthropic)" \
                    --add-password="$(_m ai_key_openai)" \
                    --add-password="$(_m ai_key_moonshot)" --separator='|')
                [ $? -eq 0 ] && [ -n "$out" ] || continue
                a=$(printf '%s' "$out" | cut -d'|' -f1)
                b=$(printf '%s' "$out" | cut -d'|' -f2)
                c=$(printf '%s' "$out" | cut -d'|' -f3)
                [ -n "$a" ] && flow_conf_set "$FLOW_AI_CONF" ANTHROPIC_API_KEY "$a"
                [ -n "$b" ] && flow_conf_set "$FLOW_AI_CONF" OPENAI_API_KEY "$b"
                [ -n "$c" ] && flow_conf_set "$FLOW_AI_CONF" MOONSHOT_API_KEY "$c"
                chmod 600 "$FLOW_AI_CONF" 2>/dev/null
                dlg_info "$(_m ai_title)" "$(_m ai_saved)"
                ;;
            refresh)
                "$FLOW_SCRIPTS/ai-status.sh" --refresh >/dev/null 2>&1
                dlg_info "$(_m ai_title)" "$(_m ai_saved)"
                ;;
        esac
    done
}

do_windows() {
    local cur pick radius bak
    cur=$(niri_radius); [ -n "$cur" ] || cur=0
    pick=$(dlg_list "$(_m windows_title)" "$(printf "$(_m windows_text)" "$cur")" \
        "● $(_m windows_round)|12" \
        "● $(_m windows_sharp)|0" \
        "← $(_m btn_cancel)|__back__") || return 0
    if [ "$pick" = "__back__" ] || [ -z "$pick" ]; then
        return 0
    fi
    radius="$pick"

    bak=$(flow_snapshot)
    sed -i -E "s/^([[:space:]]*)geometry-corner-radius[[:space:]]+[0-9]+/\1geometry-corner-radius $radius/" "$CONFIG_KDL"
    flow_apply_niri "$bak" "windows:$radius" || return 1
    dlg_info "$(_m windows_title)" "$(printf "$(_m windows_done)" "$radius")"
}

do_update()   { "$FLOW_SCRIPTS/update.sh"; }
do_rollback() { "$FLOW_SCRIPTS/rollback.sh"; }

do_sysupdate() {
    local ts backup log status
    dlg_confirm "$(_m sysupdate_title)" "$(_m sysupdate_text)" || return 0

    mkdir -p "$HOME/Backups"
    ts=$(date +%Y%m%d-%H%M%S)
    backup="$HOME/Backups/config-$ts.tar.gz"
    if ! tar -czf "$backup" -C "$HOME" .config >/dev/null 2>&1; then
        dlg_error "$(_m err_title)" "tar failed: $backup"
        return 1
    fi

    if command -v alacritty >/dev/null 2>&1; then
        env -u GTK_THEME alacritty -e bash -c \
            "$FLOW_SCRIPTS/system-update.sh; echo; read -rp 'Press Enter to close…' _" >/dev/null 2>&1
    else
        dlg_warn "$(_m sysupdate_title)" "$(_m sysupdate_running)"
        "$FLOW_SCRIPTS/system-update.sh"
    fi

    log="$FLOW_CACHE/last-system-update.log"
    status=$(cat "$FLOW_CACHE/last-system-update.status" 2>/dev/null)
    if [ "$status" = "0" ]; then
        dlg_info "$(_m sysupdate_title)" "$(_m sysupdate_ok)"$'\n\n'"$(printf "$(_m sysupdate_backup)" "$backup")"
        return 0
    fi

    if dlg_confirm "$(_m sysupdate_title)" "$(printf "$(_m sysupdate_fail)" "$log")"$'\n\n'"$(_m sysupdate_restore)"; then
        tar -xzf "$backup" -C "$HOME" >/dev/null 2>&1 \
            && dlg_info "$(_m sysupdate_title)" "$(_m sysupdate_restored)" \
            || dlg_error "$(_m err_title)" "tar -xzf failed: $backup"
        flow_restart_waybar
    fi
}

do_cleanup() { "$FLOW_SCRIPTS/cleanup.sh"; }

do_language() {
    local pick
    pick=$(dlg_list "$(_m lang_title)" "$(_m lang_text)" \
        "● $(_m lang_ru)|ru" "● $(_m lang_en)|en") || return 0
    [ -n "$pick" ] || return 0
    flow_set_lang "$pick" || return 1
    flow_i18n_load
    dlg_info "$(_m lang_title)" "$(_m lang_done)"
}

# -------------------------------------------------------------- loop ------
while true; do
    VER=$(cat "$FLOW_VERSION_FILE" 2>/dev/null); VER=${VER:-?}
    THEME="$(flow_theme_label "$(flow_theme_id)")"
    LANGNAME="$(_m lang_ru)"; [ "$(flow_lang)" = "en" ] && LANGNAME="$(_m lang_en)"
    TEXT=$(printf "$(_m menu_text)" "$VER" "$THEME" "$LANGNAME")

    CHOICE=$(dlg_list "$(_m menu_title)" "$TEXT" \
        "$(_m m_wallpaper)|wallpaper" \
        "$(_m m_locksettings)|lock" \
        "$(_m m_defaults)|defaults" \
        "$(_m m_theme)|theme" \
        "$(_m m_waybar)|waybar" \
        "$(_m m_ai)|ai" \
        "$(_m m_windows)|windows" \
        "$(_m m_update)|update" \
        "$(_m m_rollback)|rollback" \
        "$(_m m_sysupdate)|sysupdate" \
        "$(_m m_cleanup)|cleanup" \
        "$(_m m_language)|language" \
        "$(_m m_exit)|exit") || exit 0

    case "$CHOICE" in
        wallpaper) do_wallpaper || true;;
        lock)      do_lock || true;;
        defaults)  do_defaults || true;;
        theme)     do_theme || true;;
        waybar)    do_waybar || true;;
        ai)        do_ai || true;;
        windows)   do_windows || true;;
        update)    do_update || true;;
        rollback)  do_rollback || true;;
        sysupdate) do_sysupdate || true;;
        cleanup)   do_cleanup || true;;
        language)  do_language || true;;
        exit|"")   exit 0;;
    esac
done
