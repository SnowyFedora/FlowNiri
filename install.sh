#!/usr/bin/env bash
# ============================================================
#  FlowNiri — installer
#
#  Usage:
#    ./install.sh                 install packages + configs
#    ./install.sh --no-packages   configs only (no sudo, no pacman)
#    ./install.sh --dry-run       show what would be copied
#
#  The script never removes your files: everything it replaces is first
#  copied to ~/.cache/flow-niri/install-backup/<timestamp>/.
#  FlowNiri user state (theme, wallpaper, language, AI settings) is kept.
# ============================================================
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.cache/flow-niri/install-backup/$STAMP"

WITH_PACKAGES=1
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --no-packages) WITH_PACKAGES=0 ;;
        --dry-run)     DRY_RUN=1 ;;
        -h|--help)     sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

ok()   { printf '\033[32m->\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

run() { # respect --dry-run
    if [ "$DRY_RUN" -eq 1 ]; then printf '[dry-run] %s\n' "$*"; else "$@"; fi
}

[ "$(id -u)" -eq 0 ] && die "Run the installer as a normal user, not with sudo/root."
[ -f "$REPO/niri/config.kdl" ] || die "Run install.sh from the FlowNiri repository root."
command -v niri >/dev/null 2>&1 || warn "niri is not installed yet — configs are installed, validation is skipped."

# ---------------------------------------------------------------- packages --
PACKAGES=(
    niri waybar fuzzel alacritty mako gtklock swayidle swaybg
    zenity python-gobject gtk4 qt6ct qt6-wayland
    btop grim slurp satty wl-clipboard copyq nautilus
    network-manager-applet pavucontrol playerctl brightnessctl
    upower gsimplecal micro fastfetch zsh git curl unzip jq libnotify
    rofi power-profiles-daemon xdg-desktop-portal
    xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-keyring
    papirus-icon-theme ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
    # FlowNiri shell
    github-cli wf-recorder udiskie pacman-contrib swayosd
)

install_packages() {
    command -v pacman >/dev/null 2>&1 || { warn "pacman not found — skipping packages."; return 0; }
    local p missing=()
    for p in "${PACKAGES[@]}"; do
        pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        ok "All FlowNiri packages are already installed."
        return 0
    fi
    say_missing="$(printf '%s ' "${missing[@]}")"
    ok "Installing: $say_missing"
    run sudo pacman -S --needed --noconfirm "${missing[@]}" \
        || warn "Some packages could not be installed — the shell still works without them."
}

# ----------------------------------------------------------------- backups --
backup_existing() {
    local targets=(
        "$CONFIG/niri" "$CONFIG/waybar" "$CONFIG/fuzzel" "$CONFIG/scripts"
        "$CONFIG/themes" "$CONFIG/FlowNiri" "$CONFIG/alacritty" "$CONFIG/btop"
        "$CONFIG/mako" "$CONFIG/gtklock" "$CONFIG/qt6ct" "$CONFIG/xdg-desktop-portal"
        "$CONFIG/gtk-3.0" "$CONFIG/gtk-4.0" "$CONFIG/systemd/user"
    )
    local t
    mkdir -p "$BACKUP" || die "Cannot create $BACKUP"
    for t in "${targets[@]}"; do
        [ -e "$t" ] || continue
        run mkdir -p "$BACKUP/$(dirname "${t#"$HOME"/}")"
        run cp -a "$t" "$BACKUP/$(dirname "${t#"$HOME"/}")/" 2>/dev/null
    done
    [ -f "$HOME/.zshrc" ] && run cp -a "$HOME/.zshrc" "$BACKUP/.zshrc" 2>/dev/null
    ok "Existing configs backed up to $BACKUP"
}

# ----------------------------------------------------------------- configs --
install_configs() {
    local d
    for d in niri waybar fuzzel alacritty btop mako gtklock qt6ct xdg-desktop-portal themes scripts; do
        [ -d "$REPO/$d" ] || continue
        run mkdir -p "$CONFIG"
        run cp -a "$REPO/$d" "$CONFIG/"
    done
    # GTK3/GTK4 settings (gtk/ mirrors ~/.config/)
    if [ -d "$REPO/gtk" ]; then
        run cp -a "$REPO/gtk/." "$CONFIG/"
    fi

    # FlowNiri core, keeping the user's theme / wallpaper / AI state
    local f state_tmp="$BACKUP/state"
    if [ "$DRY_RUN" -eq 0 ]; then
        mkdir -p "$state_tmp"
        for f in ai.conf wallpaper.conf lang.conf theme.name waybar-order.conf; do
            [ -f "$CONFIG/FlowNiri/$f" ] && cp -a "$CONFIG/FlowNiri/$f" "$state_tmp/"
        done
    fi
    run mkdir -p "$CONFIG/FlowNiri"
    run cp -a "$REPO/FlowNiri/." "$CONFIG/FlowNiri/"
    if [ "$DRY_RUN" -eq 0 ]; then
        for f in ai.conf wallpaper.conf lang.conf theme.name waybar-order.conf; do
            [ -f "$state_tmp/$f" ] && cp -a "$state_tmp/$f" "$CONFIG/FlowNiri/$f"
        done
        chmod 600 "$CONFIG/FlowNiri/ai.conf" 2>/dev/null
    fi
    run chmod +x "$CONFIG/scripts/"*.sh 2>/dev/null
    run chmod +x "$CONFIG/FlowNiri/lib/common.sh" 2>/dev/null

    # systemd user units (AI monitor timers + portal drop-ins)
    if [ -d "$REPO/systemd/user" ]; then
        run mkdir -p "$CONFIG/systemd/user"
        run cp -a "$REPO/systemd/user/." "$CONFIG/systemd/user/"
    fi

    # .zshrc
    [ -f "$REPO/.zshrc" ] && run cp -a "$REPO/.zshrc" "$HOME/.zshrc"
}

# ------------------------------------------------------------- wallpapers --
install_wallpapers() {
    [ -d "$REPO/wallpapers" ] || return 0
    run mkdir -p "$HOME/Downloads/Wallpapers"
    run cp -a "$REPO/wallpapers/." "$HOME/Downloads/Wallpapers/"
    if [ ! -f "$HOME/Downloads/wallpaper.jpg" ]; then
        [ -f "$REPO/wallpapers/wallpaper.jpg" ] \
            && run cp -a "$REPO/wallpapers/wallpaper.jpg" "$HOME/Downloads/wallpaper.jpg"
    fi
}

# --------------------------------------------------------------- cursors ---
install_cursors() {
    [ -d "$REPO/cursors" ] || return 0
    
    run mkdir -p "$HOME/.local/share/icons"
    
    local archive
    for archive in "$REPO/cursors/"*.tar.xz "$REPO/cursors/"*.tar.gz "$REPO/cursors/"*.zip; do
        [ -f "$archive" ] || continue
        if [ "$DRY_RUN" -eq 1 ]; then
            printf '[dry-run] extract %s -> %s\n' "$archive" "$HOME/.local/share/icons"
        else
            case "$archive" in
                *.tar.xz) tar -xJf "$archive" -C "$HOME/.local/share/icons/" ;;
                *.tar.gz) tar -xzf "$archive" -C "$HOME/.local/share/icons/" ;;
                *.zip)    unzip -o "$archive" -d "$HOME/.local/share/icons/" >/dev/null ;;
            esac
        fi
    done
    
    # Принудительно применяем курсор
    if [ "$DRY_RUN" -eq 0 ] && command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
    fi
    ok "Cursor theme installed (Bibata-Modern-Ice)."
}

# ------------------------------------------------------- desktop entries --
install_desktop_entries() {
    [ -d "$REPO/FlowNiri/applications" ] || return 0
    run mkdir -p "$DATA/applications"
    run cp -f "$REPO/FlowNiri/applications/"*.desktop "$DATA/applications/"
}

# ------------------------------------------------------------ home paths --
rewrite_paths() {
    [ "$DRY_RUN" -eq 1 ] && return 0
    local target f
    for target in "$CONFIG/niri" "$CONFIG/waybar" "$CONFIG/gtklock" "$CONFIG/qt6ct" \
                  "$CONFIG/alacritty" "$CONFIG/btop" "$CONFIG/mako" "$CONFIG/fuzzel" \
                  "$CONFIG/FlowNiri" "$CONFIG/scripts" "$DATA/applications"; do
        [ -d "$target" ] || continue
        grep -rlI '/home/vladikusb' "$target" 2>/dev/null | while IFS= read -r f; do
            sed -i "s|/home/vladikusb|$HOME|g" "$f"
        done
    done
    ok "Paths rewritten to $HOME"
}

# ------------------------------------------------------------------ timers --
enable_timers() {
    [ "$DRY_RUN" -eq 1 ] && return 0
    command -v systemctl >/dev/null 2>&1 || return 0
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now flow-niri-ai-active.timer flow-niri-ai-idle.timer 2>/dev/null \
        || warn "AI timers not enabled (no user systemd session?). Enable later with: systemctl --user enable --now flow-niri-ai-active.timer flow-niri-ai-idle.timer"
}

# ------------------------------------------------------------ validation --
validate() {
    [ "$DRY_RUN" -eq 1 ] && return 0
    if command -v niri >/dev/null 2>&1; then
        if niri validate >/dev/null 2>&1; then
            ok "niri validate: OK"
        else
            warn "niri validate failed — see ~/.cache/flow-niri/last_error.log and the backup at $BACKUP"
        fi
    fi
    if [ -x "$CONFIG/scripts/theme-switcher.sh" ] && [ -f "$CONFIG/themes/$(cat "$CONFIG/FlowNiri/theme.name" 2>/dev/null).theme" ]; then
        "$CONFIG/scripts/theme-switcher.sh" --silent "$(cat "$CONFIG/FlowNiri/theme.name")" >/dev/null 2>&1 \
            && ok "Theme palette regenerated: $(cat "$CONFIG/FlowNiri/theme.name")" \
            || warn "Theme palette not regenerated (zenity/niri unavailable during install)."
    fi
}

# -------------------------------------------------------------------- main --
printf '\n\033[1mFlowNiri installer\033[0m — %s\n\n' "$REPO"

[ "$WITH_PACKAGES" -eq 1 ] && install_packages
backup_existing
install_configs
install_wallpapers
install_cursors
install_desktop_entries
rewrite_paths
enable_timers
validate

cat <<EOF

============================================================
 FlowNiri is installed.

   Menu          Mod+Shift+M   (GTK4 settings or zenity fallback)
   Hotkeys       Mod+/
   AI monitor    Mod+Shift+A
   Wallpaper     Menu -> Change wallpaper  or  scripts/wallpaper.sh
   Update        Menu -> Update shell  (requires: gh auth login)
   Theme         Menu -> Change theme   (15 palettes)

 Next steps
   1. Log out and back into the Niri session.
   2. Run "gh auth login" once, otherwise update/rollback cannot
      download releases from GitHub.
   3. Brightness and the power menu use sudo; add these lines with
      "sudo visudo" if they do not work:
      $USER ALL=(ALL) NOPASSWD: /usr/bin/brightnessctl, /usr/bin/shutdown, /usr/bin/reboot
   4. Optional: chsh -s /bin/zsh   (the repo ships a .zshrc)

 Backup of the replaced configs: $BACKUP
============================================================
EOF
