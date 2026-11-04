# FlowNiri

**A complete Niri desktop shell for Arch Linux: Niri + Waybar + Fuzzel, fifteen colour themes, a settings centre, an AI-agent monitor, wallpaper management and a safe update/rollback system.**

FlowNiri is a set of dotfiles plus the small shell that glues them together. The
compositor is [Niri](https://github.com/YaLTeR/niri) (scrollable tiling Wayland
compositor), the bar is [Waybar](https://github.com/Alexays/Waybar), the launcher
is [Fuzzel](https://codeberg.org/dnkl/fuzzel), and the settings GUI is GTK4 with
PyGObject. Everything else is plain Bash and a few small Python helpers.

> [!IMPORTANT]
> FlowNiri uses **Niri, Waybar and Fuzzel only**. It does **not** use
> **Quickshell**, Noctalia, Astal or any other Qt Quick / QML shell.
> There is no QML in this repository: the bar is Waybar, the launcher is Fuzzel,
> the control centre is GTK4, and all automation lives in `~/.config/scripts`.

- Version: **1.0.0**
- Repository: <https://github.com/SnowyFedora/FlowNiri>
- Upstream project this shell grew out of: `SnowyFedora/GruvboxDotfilesNiri`
- Languages: English / Русский (the UI and this README are bilingual)

---

## Table of contents

1. [Features](#1-features)
2. [Requirements](#2-requirements)
3. [Installation](#3-installation)
4. [Repository layout](#4-repository-layout)
5. [Keybindings](#5-keybindings)
6. [Theme switching](#6-theme-switching)
7. [Waybar](#7-waybar)
8. [AI agent monitoring](#8-ai-agent-monitoring)
9. [Wallpaper management](#9-wallpaper-management)
10. [Update and rollback system](#10-update-and-rollback-system)
11. [Settings centre](#11-settings-centre)
12. [Language / localization](#12-language--localization)
13. [Cleanup](#13-cleanup)
14. [Troubleshooting](#14-troubleshooting)
15. [Uninstall](#15-uninstall)
16. [Credits](#16-credits)
17. [Русский](#русский)

---

## 1. Features

| Area | What you get |
| --- | --- |
| Compositor | Niri with a tuned `config.kdl`: 9 workspaces, 12 px rounded corners, gaps, window rules, startup services |
| Bar | Waybar: workspaces, window title, layout, network, volume, CPU, RAM, battery, clock, tray, power menu, AI monitor |
| Launcher | Fuzzel, themed from the active palette, `Mod+D` |
| Themes | 15 palettes (Gruvbox, Catppuccin, Dracula, Nord, Tokyo Night, Kanagawa, …) applied atomically to Niri + Waybar + Fuzzel |
| Settings | GTK4 control centre (12 pages) with a Zenity fallback for minimal systems |
| AI monitor | OpenCode, Claude Code, Codex, Kimi Code and Freebuff: live state in Waybar, usage window, budgets, API keys |
| Wallpapers | `wallpaper.sh` and the GUI: pick, apply live and persist in `niri/config.kdl` |
| Updates | `gh`-based release updates, per-file backups, `niri validate` gate, automatic restore on failure |
| Rollback | Any previous release tag can be re-installed from the menu |
| System update | `pacman -Syu` + integrity check + config backup + optional config restore |
| i18n | Full English and Russian UI, switchable at runtime |
| No Quickshell | No QML shell, no Astal, no Quickshell dependency anywhere |

---

## 2. Requirements

- **Arch Linux** or an Arch-based distribution (the installer uses `pacman`).
- A **Wayland** session started from a TTY (`niri-session`) or a display manager.
- `git` and `python3` (needed by the release tooling and a few helpers).
- `gh` (GitHub CLI) for the update and rollback features.
- An internet connection for the initial package installation.

All runtime packages are installed by `install.sh`. Everything is optional in the
sense that missing tools degrade gracefully: without `gh` you cannot update the
shell, without `swayosd` the OSD falls back to `notify-send`/`mako`, and so on.

---

## 3. Installation

### 3.1 Quick install

```bash
git clone https://github.com/SnowyFedora/FlowNiri.git ~/FlowNiri
cd ~/FlowNiri
chmod +x install.sh
./install.sh
```

Log out of your current session and log back into **Niri**. The installer shows
what it installed and what to do next.

### 3.2 Installer options

| Command | Effect |
| --- | --- |
| `./install.sh` | Installs missing packages with `pacman`, then all configs |
| `./install.sh --no-packages` | Configs only — no `sudo`, no `pacman` |
| `./install.sh --dry-run` | Prints every copy it would perform, changes nothing |
| `./install.sh --help` | Short usage text |

The script refuses to run as root.

### 3.3 What the installer does

1. Detects the repository root and checks it is the FlowNiri tree.
2. Installs only the packages that are **not** installed yet (`pacman -Qq` check,
   then `pacman -S --needed --noconfirm`).
3. Backs up every config it is about to replace to
   `~/.cache/flow-niri/install-backup/<timestamp>/`.
4. Copies `niri/`, `waybar/`, `fuzzel/`, `alacritty/`, `btop/`, `mako/`,
   `gtklock/`, `qt6ct/`, `xdg-desktop-portal/`, `themes/`, `scripts/` and
   `gtk/` into `~/.config/`.
5. Installs the FlowNiri core (`FlowNiri/` → `~/.config/FlowNiri/`) while keeping
   your state files: `ai.conf`, `wallpaper.conf`, `lang.conf`, `theme.name`,
   `waybar-order.conf`.
6. Installs the systemd user units (`flow-niri-ai-*.timer` and the portal
   drop-ins) and enables the AI timers.
7. Installs the Fuzzel desktop entries (`FlowNiri Menu`, `FlowNiri AI`) into
   `~/.local/share/applications/`.
8. Copies the wallpaper to `~/Downloads/Wallpapers/` and, if no wallpaper exists
   yet, to `~/Downloads/wallpaper.jpg` (the path used by `config.kdl`).
9. Copies `.zshrc` to `~`.
10. Replaces the hard-coded author path `/home/vladikusb` with your real `$HOME`
    in every installed config, script and desktop entry.
11. Regenerates the GTK palette for the active theme and runs `niri validate`.

### 3.4 After the first install

```bash
# 1. Required for "Update shell" / "Roll back version"
gh auth login

# 2. Reload the session
#    Niri: Mod+Shift+E -> re-login, or log out from your display manager

# 3. Optional: make Zsh your shell (the repo ships .zshrc)
chsh -s /bin/zsh

# 4. Optional: brightness keys and the shutdown/reboot menu use sudo
sudo visudo
# add:
# youruser ALL=(ALL) NOPASSWD: /usr/bin/brightnessctl, /usr/bin/shutdown, /usr/bin/reboot
```

Oh My Zsh, the Agnoster theme and the usual plugins are **not** installed
automatically; the shipped `.zshrc` expects them if you want the full prompt.

### 3.5 Manual installation

If you prefer to copy things yourself, the mapping is:

| Repository path | Installed to |
| --- | --- |
| `niri/` | `~/.config/niri/` |
| `waybar/` | `~/.config/waybar/` |
| `fuzzel/` | `~/.config/fuzzel/` |
| `scripts/` | `~/.config/scripts/` |
| `themes/*.theme` | `~/.config/themes/` |
| `FlowNiri/` | `~/.config/FlowNiri/` |
| `flowNiri` desktop entries | `~/.local/share/applications/` |
| `systemd/user/` | `~/.config/systemd/user/` |
| `gtk/gtk-3.0`, `gtk/gtk-4.0` | `~/.config/gtk-3.0`, `~/.config/gtk-4.0` |
| `alacritty/`, `btop/`, `mako/`, `gtklock/`, `qt6ct/`, `xdg-desktop-portal/` | `~/.config/<name>/` |
| `wallpapers/wallpaper.jpg` | `~/Downloads/wallpaper.jpg` |
| `.zshrc` | `~/.zshrc` |

Then reload Niri and enable the timers:

```bash
systemctl --user daemon-reload
systemctl --user enable --now flow-niri-ai-active.timer flow-niri-ai-idle.timer
```

---

## 4. Repository layout

```text
FlowNiri/
├── install.sh                     # installer (packages + configs)
├── release.sh                     # builds the release ZIP, tags and publishes
├── README.md
├── .zshrc
├── niri/config.kdl                # compositor config, binds, window rules
├── waybar/
│   ├── config.jsonc               # modules and click actions
│   ├── style.css                  # palette applied by theme-switcher.sh
│   └── scripts/layout.sh          # keyboard layout helper
├── fuzzel/fuzzel.ini              # launcher theme
├── themes/                        # 15 palettes: NAME_EN, BG, FG, ACCENT, …
├── scripts/                       # all shell automation
│   ├── flowniri-settings.sh       # GTK4 settings centre launcher
│   ├── flowniri-menu.sh           # Zenity menu (fallback / classic UI)
│   ├── flowniri-cli.sh            # headless CLI used by the settings app
│   ├── theme-switcher.sh          # palette swap for niri/waybar/fuzzel
│   ├── apply_theme-switcher.sh    # light/dark mode for GTK3/GTK4/Qt
│   ├── wallpaper.sh               # wallpaper backend
│   ├── ai-status.sh               # AI usage collector (Waybar/timers)
│   ├── ai-launcher.sh             # AI status window
│   ├── hotkeys.sh                 # hotkey overlay parser
│   ├── update.sh / rollback.sh    # release update / rollback
│   ├── system-update.sh           # pacman update with config backup
│   ├── cleanup.sh                 # safe, confirmation-based cleanup
│   ├── osd.sh                     # volume/brightness OSD
│   ├── screenshot.sh / record.sh  # screenshots and screen recording
│   └── idle.sh / power_menu.sh    # idle/lock and power menu
├── FlowNiri/                      # the shell core → ~/.config/FlowNiri/
│   ├── manifest.txt               # files owned by FlowNiri (update scope)
│   ├── .version                   # installed release version
│   ├── lang.conf / theme.name / ai.conf
│   ├── packages.txt               # packages a release may need
│   ├── lib/common.sh              # shared functions (i18n, backups, releases)
│   ├── i18n/en.conf, i18n/ru.conf # UI strings
│   ├── ui/settings.py, settings.css  # GTK4 control centre
│   ├── templates/gtk4.css         # generated GTK palette template
│   └── applications/*.desktop     # Fuzzel entries
├── systemd/user/                  # AI timers + portal drop-ins
├── gtk/gtk-3.0, gtk/gtk-4.0       # GTK settings
├── alacritty/ btop/ mako/ gtklock/ qt6ct/ xdg-desktop-portal/
└── wallpapers/wallpaper.jpg
```

---

## 5. Keybindings

`Mod` is the Super/Windows key. The full, always up-to-date list is generated
from `niri/config.kdl` by `scripts/hotkeys.sh` and shown with **`Mod+/`**
(Fuzzel) or **`Mod+Shift+/`** (Niri's own overlay, English labels).

### 5.1 FlowNiri

| Shortcut | Action |
| --- | --- |
| `Mod+Shift+M` | Open the FlowNiri settings centre (GTK4, Zenity fallback) |
| `Mod+/` | Hotkey overlay, generated from `config.kdl` |
| `Mod+Shift+A` | AI agent monitor window |
| `Mod+Shift+W` | Settings → Wallpaper page |
| `Mod+Shift+S` | Region screenshot, edit in Satty, copy to clipboard |
| `Mod+Print` | Full-screen screenshot to clipboard |
| `Mod+Alt+R` | Start/stop screen recording (`wf-recorder` → `~/Videos/FlowNiri`) |
| `Mod+V` | Clipboard manager (`copyq`) |
| `Mod+Escape` | Lock screen (`gtklock`) |
| `Super+Alt+L` | Lock screen (`gtklock`) |

### 5.2 Applications and session

| Shortcut | Action |
| --- | --- |
| `Mod+T` | Terminal (`alacritty`) |
| `Mod+D` | Launcher (`fuzzel`) |
| `Mod+E` | File manager (`nautilus`, floating) |
| `Mod+O` | Overview |
| `Mod+Q` | Close window |
| `Mod+Shift+E` | Quit Niri (with confirmation) |
| `Ctrl+Alt+Delete` | Quit Niri (with confirmation) |
| `Mod+Shift+P` | Power off monitors |

### 5.3 Windows and columns

| Shortcut | Action |
| --- | --- |
| `Mod+←/↓/↑/→` or `Mod+H/J/K/L` | Focus column/window |
| `Mod+Ctrl+←/↓/↑/→` or `Mod+Ctrl+H/J/K/L` | Move column/window |
| `Mod+Shift+←/↓/↑/→` or `Mod+Shift+H/J/K/L` | Focus monitor |
| `Mod+Ctrl+Shift+arrows` | Move column to another monitor |
| `Mod+R` / `Mod+Shift+R` | Next / previous preset column width |
| `Mod+Ctrl+R` / `Mod+Ctrl+Shift+R` | Reset / cycle window height |
| `Mod+Minus` / `Mod+Equal` | Narrower / wider column (−10 % / +10 %) |
| `Mod+Shift+Minus` / `Mod+Shift+Equal` | Shorter / taller window |
| `Mod+F` | Toggle floating |
| `Mod+Shift+V` | Switch focus floating ↔ tiling |
| `Mod+Shift+F` | Fullscreen |
| `Mod+X` / `Mod+M` | Maximize column / maximize to edges |
| `Mod+C` / `Mod+Ctrl+C` | Center column / center all visible columns |
| `Mod+W` | Tabbed column display |
| `Mod+[` / `Mod+]` | Consume or expel window left/right |
| `Mod+,` / `Mod+.` | Consume window into column / expel from column |
| `Mod+Home` / `Mod+End` | Focus first / last column |
| `Mod+Ctrl+Home` / `Mod+Ctrl+End` | Move column first / last |

### 5.4 Workspaces

| Shortcut | Action |
| --- | --- |
| `Mod+1…9` | Focus workspace 1–9 |
| `Mod+Ctrl+1…9` | Move column to workspace 1–9 |
| `Mod+Page_Down` / `Mod+Page_Up`, `Mod+U` / `Mod+I` | Next / previous workspace |
| `Mod+Shift+Page_Down` / `Mod+Shift+Page_Up`, `Mod+Shift+U` / `Mod+Shift+I` | Move workspace down / up |
| `Mod+Ctrl+Page_Down` / `Mod+Ctrl+Page_Up` | Move column to next / previous workspace |
| `Mod+wheel` (vertical) | Switch workspace |
| `Mod+Shift+wheel` | Focus columns |

### 5.5 Media and hardware keys

| Key | Action |
| --- | --- |
| Volume up / down / mute | `wpctl` through `scripts/osd.sh`, OSD via `swayosd` → `mako` |
| Mic mute | `osd.sh mic-mute` |
| Brightness up / down | `brightnessctl` through `osd.sh` (needs the sudoers rule) |
| Play / pause / stop / previous / next | `playerctl` |
| `Print`, `Ctrl+Print`, `Alt+Print` | Niri's own screenshot actions |

---

## 6. Theme switching

FlowNiri ships **15 complete palettes**. A theme is one small file in
`~/.config/themes/<id>.theme`; the switcher rewrites the colours inside
`waybar/style.css`, `fuzzel/fuzzel.ini` and `niri/config.kdl`.

| ID | Name |
| --- | --- |
| `ayu-dark` | Ayu Dark |
| `catppuccin-macchiato` | Catppuccin Macchiato |
| `catppuccin-mocha` | Catppuccin Mocha |
| `dracula` | Dracula |
| `everforest` | Everforest |
| `gruvbox-dark` | Gruvbox Dark |
| `gruvbox-light` | Gruvbox Light |
| `gruvbox-material` | Gruvbox Material |
| `kanagawa` | Kanagawa |
| `monochrome` | Monochrome |
| `nord` | Nord |
| `one-dark` | One Dark |
| `rose-pine` | Rose Pine |
| `solarized-dark` | Solarized Dark |
| `tokyonight` | Tokyo Night |

### 6.1 From the GUI

1. Press `Mod+Shift+M`.
2. Open **Themes / Темы**.
3. Pick a palette. The bar, the launcher, the Niri borders and the dialogs change
   immediately; Waybar is restarted for you.

The classic Zenity menu (`FlowNiri Menu → Change theme`) does the same on systems
without GTK4/PyGObject.

### 6.2 From the CLI

```bash
~/.config/scripts/theme-switcher.sh --list          # all ids
~/.config/scripts/theme-switcher.sh monochrome      # apply
~/.config/scripts/theme-switcher.sh --silent nord   # no notification
~/.config/scripts/apply_theme-switcher.sh           # re-apply GTK light/dark
~/.config/scripts/apply_theme-switcher.sh --mode light gruvbox-light
```

### 6.3 How it works (and why it is safe)

- Every palette key (`BG`, `FG`, `ACCENT`, `RED`, …) has a **unique hex value**
  inside a theme; the switcher validates completeness before touching anything.
- Colours are swapped through temporary placeholders (`__FN0__`, `__FN1__`, …),
  so two themes sharing a hex value can never cascade into each other.
- A snapshot of the affected files is taken first
  (`~/.cache/flow-niri/backup/<timestamp>/`).
- `niri validate` runs after the swap. If it fails, all files are restored, the
  session is **not** reloaded and the error is written to
  `~/.cache/flow-niri/last_error.log`.
- Only the FlowNiri palette is recoloured. GTK applications stay on standard
  **Adwaita / Adwaita-dark**, controlled by `apply_theme-switcher.sh`
  (light/dark detection from `MODE=`, the theme name, or the BG luminance).
  This is intentional: recolouring libadwaita globally used to break Nautilus
  and Firefox.

### 6.4 Adding your own theme

Copy an existing file and keep every key, changing only the values:

```bash
cp ~/.config/themes/monochrome.theme ~/.config/themes/my-theme.theme
$EDITOR ~/.config/themes/my-theme.theme
~/.config/scripts/theme-switcher.sh --list
```

Required keys: `BG BG_HARD BG_SOFT BG_SEL BORDER FG FG_STRONG FG_DIM GRAY MUTED
ACCENT ACCENT_2 RED RED_BRIGHT GREEN GREEN_BRIGHT BLUE PURPLE ORANGE`.
Optional: `NAME_EN`, `NAME_RU`, `MODE=light|dark`. No `#` before the hex values,
and no duplicate values inside one theme.

---

## 7. Waybar

`waybar/config.jsonc` defines a single row:

- **Left:** `niri/workspaces`
- **Centre:** `niri/window`
- **Right:** `niri/language`, `network`, `pulseaudio`, `cpu`, `memory`, `battery`,
  `clock`, `tray`, `custom/power`, `custom/ai-status`

Notable behaviour:

| Module | Click action |
| --- | --- |
| Language | `niri msg action switch-layout next` |
| Network | `nm-connection-editor` |
| Volume | `pavucontrol` |
| CPU / RAM | `btop` in Alacritty |
| Battery | `upower` report |
| Clock | `gsimplecal` |
| Power | `scripts/power_menu.sh` |
| AI | `scripts/ai-launcher.sh` |

Modules can be toggled from **Settings → Panel** or
`FlowNiri Menu → Configure Waybar`. Their order is stored in
`~/.config/FlowNiri/waybar-order.conf`, so a disabled module returns to the same
slot when re-enabled. The bar is restarted (not the session) after every change.

---

## 8. AI agent monitoring

FlowNiri watches your coding agents and puts their state in Waybar.

### 8.1 Supported agents

| ID | Agent | Local data used |
| --- | --- | --- |
| `opencode` | OpenCode | `~/.local/share/opencode` (`opencode.db`) or `~/.opencode` |
| `claude` | Claude Code | `~/.claude` / `~/.config/claude`, `*.jsonl` usage |
| `codex` | Codex | `~/.codex` / `~/.config/codex`, session `*.jsonl` |
| `kimi` | Kimi Code | `~/.kimi`, `~/.moonshot`, `~/.config/kimi` |
| `freebuff` | Freebuff | `~/.freebuff`, `~/.config/freebuff`, `~/.local/share/freebuff` |

### 8.2 State detection

The monitor is hybrid: a process check (`pgrep -u $USER -f <agent>`) plus real
session activity (files modified recently in the agent's data directory).

| State | Meaning |
| --- | --- |
| `active` | The process runs and its data changed in the last 5 minutes |
| `idle` | The process runs but has been quiet, or the data changed in the last 2 minutes |
| `absent` | No process and no recent activity |

### 8.3 Timers and polling

| Unit | Interval | Purpose |
| --- | --- | --- |
| `flow-niri-ai-active.timer` | every 30 s | An agent is alive — keep the numbers fresh |
| `flow-niri-ai-idle.timer` | 5 min tick, 15 min gate | Nothing runs — poll rarely |

```bash
systemctl --user status flow-niri-ai-active.timer flow-niri-ai-idle.timer
systemctl --user list-timers 'flow-niri-ai-*'
```

The cache is `~/.cache/flow-niri/ai-usage.json`; it is written atomically and
protected by a lock, so the Waybar module (which reads it every 30 s) never
blocks and never spawns heavy work.

### 8.4 Configuration — `~/.config/FlowNiri/ai.conf`

The file is installed with mode `600` and is **never overwritten** by updates.

| Key | Meaning |
| --- | --- |
| `ENABLED=1\|0` | Master switch (also `Settings → AI agents`) |
| `AGENTS=a,b,c` | Which agents to watch |
| `LIMIT_<ID>=<tokens>` | Budget per agent for a 5-hour window; `0` disables the percentage |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `MOONSHOT_API_KEY` | Optional keys for provider-reported usage |
| `ANTHROPIC_USAGE_URL`, `OPENAI_USAGE_URL` | Optional usage endpoints (`curl --max-time 5`) |

A percentage is only shown when it is real: either the provider reports it, or
the agent's local token counter is compared with `LIMIT_<ID>`. Otherwise the
module shows `—` instead of inventing a number.

### 8.5 Using it

```bash
~/.config/scripts/ai-status.sh --refresh     # collect now
~/.config/scripts/ai-status.sh --waybar      # JSON for Waybar
~/.config/scripts/ai-status.sh --details     # human-readable report
~/.config/scripts/ai-launcher.sh             # status window (Mod+Shift+A)
```

The same options exist in **Settings → AI agents** (enable/disable, per-agent
checkboxes, budgets, keys, "Refresh now") and in the Zenity menu. Nothing leaves
your machine unless you configure one of the optional usage URLs.

---

## 9. Wallpaper management

`scripts/wallpaper.sh` is the single backend; the GUI and the CLI both use it.

```bash
~/.config/scripts/wallpaper.sh get                  # "<path>|<mode>"
~/.config/scripts/wallpaper.sh list                 # candidate images
~/.config/scripts/wallpaper.sh modes                # fill fit stretch center tile
~/.config/scripts/wallpaper.sh set ~/Pictures/a.jpg fill
```

- **GUI:** `Mod+Shift+W` opens Settings → Wallpaper; **FlowNiri Menu → Change
  wallpaper** does the same with a file chooser.
- Only the `spawn-at-startup "swaybg" …` line of `niri/config.kdl` is edited.
  The whole config is validated and restored on failure.
- The wallpaper is applied **live** through `niri msg action spawn` — no session
  restart.
- The chosen file and mode are remembered in
  `~/.config/FlowNiri/wallpaper.conf`.
- Supported modes: `fill`, `fit`, `stretch`, `center`, `tile`.
- The repository ships `wallpapers/wallpaper.jpg`; the installer copies it to
  `~/Downloads/wallpaper.jpg` if that file does not exist yet.

---

## 10. Update and rollback system

FlowNiri updates itself from GitHub Releases of
[`SnowyFedora/FlowNiri`](https://github.com/SnowyFedora/FlowNiri) using the
GitHub CLI. `gh auth login` is required once; there is no `curl` call to the API.

### 10.1 Release model

- Every release is a tag `vX.Y.Z` with one asset: `FlowNiri-X.Y.Z.zip`.
- The archive has a **top-level `FlowNiri/` folder**, like this:

  ```text
  FlowNiri/
  ├── install.sh
  ├── README.md
  ├── niri/config.kdl
  ├── scripts/…
  ├── themes/…
  └── FlowNiri/            # the shell core (manifest, i18n, UI, lib)
      ├── manifest.txt
      └── .version
  ```

- The installed version is stored in `~/.config/FlowNiri/.version`.
- `FlowNiri/manifest.txt` lists the files FlowNiri owns. **Only those files can
  be replaced.** Your state files — `theme.name`, `lang.conf`, `ai.conf` — are
  never overwritten.
- GitHub's auto-generated "Source code" archives are rejected: they have no
  `FlowNiri/` root.

### 10.2 Update shell

`Settings → Updates → Update shell` or `FlowNiri Menu → Update shell`
(`scripts/update.sh`):

1. Reads the newest tag with `gh release list` and compares it with `.version`.
2. Asks for confirmation if a newer release exists.
3. Downloads the ZIP with `gh release download` into a temp directory.
4. Verifies the archive and the `FlowNiri/` layout.
5. Backs up every manifest file to `~/.cache/flow-niri/backup/<timestamp>/`.
6. Copies the manifest files into `~/.config/`, keeps scripts executable, and
   rewrites the home path in the desktop entries.
7. Updates `.version`, runs `niri validate`, restarts Waybar.
8. Checks `FlowNiri/packages.txt` and **tells** you which packages are missing —
   it never runs `pacman` with `sudo` and never ends your session.

If validation fails, everything is restored from the backup, the compositor is
not reloaded, and the error is written to `~/.cache/flow-niri/last_error.log`.

### 10.3 Roll back

`Settings → Updates → Roll back` or `FlowNiri Menu → Roll back version`
(`scripts/rollback.sh`):

1. Lists all release tags (newest first, current one marked).
2. Downloads and verifies the selected release.
3. Applies exactly the same backup → replace → validate pipeline as an update,
   then writes that tag's version into `.version`.

Only FlowNiri files are reverted. Packages are never downgraded automatically.

### 10.4 System update

`FlowNiri Menu → Update system` (`scripts/system-update.sh`) is a different
operation:

1. Creates a `tar.gz` archive of `~/.config` in `~/Backups/`.
2. Runs `pacman -Syu` in a terminal window.
3. Runs the integrity check `pacman -Dk`.
4. Cleans the package cache with `paccache`.
5. If the update fails, offers to restore `~/.config` from the archive.

Package rollback is not possible — only configs can be restored. The log is
`~/.cache/flow-niri/last-system-update.log`.

### 10.5 Building a release (maintainers)

```bash
cd ~/FlowNiri
./release.sh --version 1.1.0 --notes "What changed"
./release.sh --dry-run --version 1.1.0     # build the ZIP only
```

`release.sh` packs the whole tree (`.git`, old ZIPs and `__pycache__` excluded)
into `FlowNiri-<version>.zip` with a `FlowNiri/` root, verifies the layout,
commits, creates/pushes the tag, and publishes the GitHub release with the
archive attached. The default source is `~/FlowNiri`; override with
`FLOWNIRI_SRC`.

### 10.6 Backups and logs

| Path | Content |
| --- | --- |
| `~/.cache/flow-niri/backup/<timestamp>/` | Manifest files before an update/rollback/theme change |
| `~/.cache/flow-niri/install-backup/<timestamp>/` | Configs replaced by `install.sh` |
| `~/.cache/flow-niri/last_error.log` | Last `niri validate` failure (before/after restore) |
| `~/.cache/flow-niri/flow.log` | Action log |
| `~/.cache/flow-niri/ai-usage.json` | AI monitor cache |
| `~/Backups/` | `~/.config` archives from the system update |

---

## 11. Settings centre

`Mod+Shift+M` opens `FlowNiri/ui/settings.py` — a GTK4 window with a sidebar:

| Page | Contents |
| --- | --- |
| Themes / Темы | 15 palettes, live preview of the current one |
| Wallpaper | File picker + mode |
| Windows | Corner radius (0 or 12), gap-related behaviour |
| Panel | Toggle Waybar modules, restart the bar |
| Keys | Read-only keybinding list, open `config.kdl` |
| Lock | Lock and suspend timers (`idle.sh`) |
| Apps | Default browser, file manager, editor |
| AI | Monitoring switch, agents, budgets, API keys, live status |
| Updates | Update shell, roll back |
| Cleanup | Safe removal of outdated files |
| Language | English / Русский |
| About | Version, repository, paths |

If PyGObject/GTK4 is missing, `flowniri-settings.sh` transparently falls back to
the Zenity menu (`flowniri-menu.sh`). The same actions are available headlessly
through `flowniri-cli.sh`:

```bash
~/.config/scripts/flowniri-cli.sh status
~/.config/scripts/flowniri-cli.sh radius 12
~/.config/scripts/flowniri-cli.sh idle 5 15
~/.config/scripts/flowniri-cli.sh lang ru
~/.config/scripts/flowniri-cli.sh waybar-toggle network
~/.config/scripts/flowniri-cli.sh ai-toggle 1
~/.config/scripts/flowniri-cli.sh hotkeys
```

---

## 12. Language / localization

- UI strings live in `~/.config/FlowNiri/i18n/en.conf` and `ru.conf`.
- The active language is `LANG=ru|en` in `~/.config/FlowNiri/lang.conf`.
- Switch it from **Settings → Language**, the Zenity menu, or
  `flowniri-cli.sh lang ru`.
- The keybinding overlay (`Mod+/`) is generated in the active language; Niri's
  own overlay is English by design.

---

## 13. Cleanup

`scripts/cleanup.sh` (Settings → Cleanup, or `FlowNiri Menu → Clean up old
files`) builds a list of candidates — desktop entries created by older
installers and FlowNiri scripts that are no longer referenced — shows it with
checkboxes, and deletes **only** what you tick. Nothing is deleted
automatically, and packages, dependencies and system files are never touched.

---

## 14. Troubleshooting

| Symptom | Fix |
| --- | --- |
| Settings centre does not open | `python3 -c 'import gi; gi.require_version("Gtk","4.0")'` — install `python-gobject gtk4`, or use `flowniri-menu.sh` |
| "Could not reach GitHub" | `gh auth login`, then retry |
| Update says the archive is broken | The release has no `FlowNiri/` folder; use the project ZIP asset, not GitHub's source archive |
| Niri config rejected after a change | See `~/.cache/flow-niri/last_error.log`; the previous files are in `~/.cache/flow-niri/backup/` |
| Waybar disappeared | `env -u GTK_THEME waybar &` or Settings → Panel → Restart bar |
| AI module shows `—` / `N/A` | No agent running, no local data, or `LIMIT_<ID>=0`; check `ai.conf` and `ai-status.sh --details` |
| Brightness keys do nothing | Add the `brightnessctl` sudoers rule (section 3.4) |
| GTK apps look like Adwaita | Intentional: the FlowNiri palette covers Niri/Waybar/Fuzzel only |
| Timers not running | `systemctl --user enable --now flow-niri-ai-active.timer flow-niri-ai-idle.timer` |
| Paths still point to another user | `grep -rl /home/vladikusb ~/.config` and replace with your `$HOME` |

---

## 15. Uninstall

```bash
systemctl --user disable --now flow-niri-ai-active.timer flow-niri-ai-idle.timer
rm -rf ~/.config/{FlowNiri,themes,scripts,niri,waybar,fuzzel,alacritty,btop,mako,gtklock,qt6ct,xdg-desktop-portal}
rm -rf ~/.local/share/applications/flowniri-*.desktop
rm -rf ~/.cache/flow-niri
# optional: ~/.zshrc, ~/Downloads/Wallpapers, ~/.config/gtk-3.0, ~/.config/gtk-4.0
```

Packages are never removed automatically; remove them with `pacman -Rns` if you
no longer need them.

---

## 16. Credits

- [Niri](https://github.com/YaLTeR/niri) — scrollable tiling Wayland compositor
- [Waybar](https://github.com/Alexays/Waybar), [Fuzzel](https://codeberg.org/dnkl/fuzzel), [Alacritty](https://github.com/alacritty/alacritty)
- [Catppuccin](https://github.com/catppuccin), [Gruvbox](https://github.com/morhetz/gruvbox), [Dracula](https://draculatheme.com), [Nord](https://www.nordtheme.com), [Tokyo Night](https://github.com/folke/tokyonight.nvim) and the other palettes for the colours
- Author: **VladikUSB** / [SnowyFedora](https://github.com/SnowyFedora)

No license file is included yet; treat the repository as the author's personal
dotfiles unless a license is added.

---

<a id="русский"></a>

# FlowNiri — Русский

**Готовая оболочка рабочего стола Niri для Arch Linux: Niri + Waybar + Fuzzel, пятнадцать цветовых тем, центр настроек, монитор ИИ-агентов, управление обоями и безопасная система обновления/отката.**

FlowNiri — это набор конфигов плюс небольшая оболочка, которая их связывает.
Композитор — [Niri](https://github.com/YaLTeR/niri) (прокручиваемый тайловый
Wayland-композитор), панель — [Waybar](https://github.com/Alexays/Waybar),
лаунчер — [Fuzzel](https://codeberg.org/dnkl/fuzzel), центр настроек — GTK4 на
PyGObject. Всё остальное — обычный Bash и несколько небольших Python-скриптов.

> [!IMPORTANT]
> FlowNiri использует **только Niri, Waybar и Fuzzel**. Проект **не использует
> Quickshell**, Noctalia, Astal и любые другие Qt Quick / QML-оболочки.
> В репозитории нет QML: панель — Waybar, лаунчер — Fuzzel, центр настроек —
> GTK4, вся автоматизация — в `~/.config/scripts`.

- Версия: **1.0.0**
- Репозиторий: <https://github.com/SnowyFedora/FlowNiri>
- Языки: English / Русский

## Содержание

1. [Возможности](#возможности)
2. [Требования](#требования)
3. [Установка](#установка)
4. [Структура репозитория](#структура-репозитория)
5. [Горячие клавиши](#горячие-клавиши)
6. [Смена темы](#смена-темы)
7. [Waybar](#waybar-1)
8. [Мониторинг ИИ-агентов](#мониторинг-ии-агентов)
9. [Управление обоями](#управление-обоями)
10. [Обновление и откат](#обновление-и-откат)
11. [Центр настроек](#центр-настроек)
12. [Язык интерфейса](#язык-интерфейса)
13. [Очистка](#очистка)
14. [Решение проблем](#решение-проблем)
15. [Удаление](#удаление)

## Возможности

| Область | Что вы получаете |
| --- | --- |
| Композитор | Niri с настроенным `config.kdl`: 9 рабочих столов, скругление 12 px, отступы, правила окон, автозапуск |
| Панель | Waybar: рабочие столы, заголовок окна, раскладка, сеть, звук, CPU, RAM, батарея, часы, трей, меню питания, ИИ-модуль |
| Лаунчер | Fuzzel в цветах активной темы, `Mod+D` |
| Темы | 15 палитр (Gruvbox, Catppuccin, Dracula, Nord, Tokyo Night, Kanagawa и др.), атомарно применяются к Niri + Waybar + Fuzzel |
| Настройки | Центр управления GTK4 (12 страниц) и резервное меню на Zenity |
| ИИ-монитор | OpenCode, Claude Code, Codex, Kimi Code и Freebuff: состояние в Waybar, расход за окно, бюджеты, API-ключи |
| Обои | `wallpaper.sh` и GUI: выбор, живое применение и сохранение в `niri/config.kdl` |
| Обновления | Обновление из релизов GitHub через `gh`, бэкап каждого файла, проверка `niri validate`, автооткат при ошибке |
| Откат | Любой предыдущий тег можно вернуть из меню |
| Обновление системы | `pacman -Syu` + проверка целостности + бэкап конфигов + восстановление |
| Локализация | Полный русский и английский интерфейс, переключается на ходу |
| Без Quickshell | Никакого QML, Astal и Quickshell |

## Требования

- **Arch Linux** или основанный на Arch дистрибутив (установщик использует `pacman`).
- Сессия **Wayland**, запущенная из TTY (`niri-session`) или из дисплей-менеджера.
- `git` и `python3` (нужны для релизов и нескольких вспомогательных скриптов).
- `gh` (GitHub CLI) для обновления и отката.
- Интернет для первичной установки пакетов.

Все рабочие пакеты ставит `install.sh`. Всё остальное опционально: без `gh` не
будет обновлений оболочки, без `swayosd` OSD переключится на
`notify-send`/`mako` и т. д.

## Установка

```bash
git clone https://github.com/SnowyFedora/FlowNiri.git ~/FlowNiri
cd ~/FlowNiri
chmod +x install.sh
./install.sh
```

Затем выйдите из сессии и войдите снова в **Niri**.

| Команда | Действие |
| --- | --- |
| `./install.sh` | Доставляет недостающие пакеты через `pacman`, затем конфиги |
| `./install.sh --no-packages` | Только конфиги — без `sudo` и `pacman` |
| `./install.sh --dry-run` | Показывает, что будет скопировано, ничего не меняя |
| `./install.sh --help` | Краткая справка |

Скрипт отказывается работать от root.

**Что делает установщик:**

1. Проверяет, что запущен из корня репозитория FlowNiri.
2. Ставит только отсутствующие пакеты (`pacman -Qq`, затем
   `pacman -S --needed --noconfirm`).
3. Делает бэкап всех заменяемых конфигов в
   `~/.cache/flow-niri/install-backup/<время>/`.
4. Копирует `niri/`, `waybar/`, `fuzzel/`, `alacritty/`, `btop/`, `mako/`,
   `gtklock/`, `qt6ct/`, `xdg-desktop-portal/`, `themes/`, `scripts/` и `gtk/`
   в `~/.config/`.
5. Устанавливает ядро FlowNiri (`FlowNiri/` → `~/.config/FlowNiri/`), сохраняя
   ваши файлы состояния: `ai.conf`, `wallpaper.conf`, `lang.conf`,
   `theme.name`, `waybar-order.conf`.
6. Ставит пользовательские unit-файлы systemd (`flow-niri-ai-*.timer` и
   drop-in для порталов) и включает таймеры ИИ.
7. Добавляет ярлыки Fuzzel (`FlowNiri Menu`, `FlowNiri AI`) в
   `~/.local/share/applications/`.
8. Копирует обои в `~/Downloads/Wallpapers/`, а если обоев ещё нет — в
   `~/Downloads/wallpaper.jpg` (этот путь указан в `config.kdl`).
9. Копирует `.zshrc` в домашний каталог.
10. Заменяет жёстко прописанный путь `/home/vladikusb` на ваш реальный `$HOME`
    во всех конфигах, скриптах и ярлыках.
11. Перегенерирует GTK-палитру активной темы и запускает `niri validate`.

**После установки:**

```bash
gh auth login          # обязательно для «Обновить оболочку» и «Откат версий»
chsh -s /bin/zsh       # опционально, в репозитории есть .zshrc
sudo visudo            # для яркости и меню питания
# добавьте:
# ваш_пользователь ALL=(ALL) NOPASSWD: /usr/bin/brightnessctl, /usr/bin/shutdown, /usr/bin/reboot
```

Oh My Zsh, тема Agnoster и плагины автоматически **не** ставятся; `.zshrc`
рассчитан на них, если нужен полный промпт.

**Ручная установка:** `niri/` → `~/.config/niri/`, `waybar/` →
`~/.config/waybar/`, `fuzzel/` → `~/.config/fuzzel/`, `scripts/` →
`~/.config/scripts/`, `themes/*.theme` → `~/.config/themes/`, `FlowNiri/` →
`~/.config/FlowNiri/`, `systemd/user/` → `~/.config/systemd/user/`, `gtk/*` →
`~/.config/gtk-3.0` и `~/.config/gtk-4.0`, ярлыки — в
`~/.local/share/applications/`, `.zshrc` → `~/.zshrc`, обои —
`~/Downloads/wallpaper.jpg`. Затем:

```bash
systemctl --user daemon-reload
systemctl --user enable --now flow-niri-ai-active.timer flow-niri-ai-idle.timer
```

## Структура репозитория

```text
FlowNiri/
├── install.sh                     # установщик (пакеты + конфиги)
├── release.sh                     # сборка ZIP, тег и публикация релиза
├── README.md
├── .zshrc
├── niri/config.kdl                # конфиг композитора: привязки, правила окон
├── waybar/                        # config.jsonc, style.css, scripts/layout.sh
├── fuzzel/fuzzel.ini
├── themes/                        # 15 палитр
├── scripts/                       # вся автоматизация на Bash
├── FlowNiri/                      # ядро оболочки → ~/.config/FlowNiri/
│   ├── manifest.txt               # файлы, которыми владеет FlowNiri
│   ├── .version                   # установленная версия
│   ├── lang.conf / theme.name / ai.conf
│   ├── lib/common.sh              # общие функции (i18n, бэкапы, релизы)
│   ├── i18n/en.conf, i18n/ru.conf
│   ├── ui/settings.py             # центр настроек GTK4
│   ├── templates/gtk4.css
│   └── applications/*.desktop
├── systemd/user/                  # таймеры ИИ и drop-in порталов
├── gtk/, alacritty/, btop/, mako/, gtklock/, qt6ct/, xdg-desktop-portal/
└── wallpapers/wallpaper.jpg
```

## Горячие клавиши

`Mod` — это клавиша Super/Windows. Полный список всегда генерируется из
`niri/config.kdl` скриптом `scripts/hotkeys.sh` и показывается по **`Mod+/`**
(Fuzzel) или **`Mod+Shift+/`** (оверлей Niri).

### FlowNiri

| Клавиши | Действие |
| --- | --- |
| `Mod+Shift+M` | Центр настроек FlowNiri (GTK4, резерв — Zenity) |
| `Mod+/` | Оверлей горячих клавиш из `config.kdl` |
| `Mod+Shift+A` | Окно монитора ИИ-агентов |
| `Mod+Shift+W` | Настройки → Обои |
| `Mod+Shift+S` | Скриншот области, редактирование в Satty, копия в буфер |
| `Mod+Print` | Скриншот всего экрана в буфер |
| `Mod+Alt+R` | Старт/стоп записи экрана (`wf-recorder` → `~/Videos/FlowNiri`) |
| `Mod+V` | Менеджер буфера обмена (`copyq`) |
| `Mod+Escape`, `Super+Alt+L` | Блокировка экрана (`gtklock`) |

### Приложения и сессия

| Клавиши | Действие |
| --- | --- |
| `Mod+T` | Терминал (`alacritty`) |
| `Mod+D` | Лаунчер (`fuzzel`) |
| `Mod+E` | Файловый менеджер (`nautilus`, плавающий) |
| `Mod+O` | Обзор |
| `Mod+Q` | Закрыть окно |
| `Mod+Shift+E`, `Ctrl+Alt+Delete` | Выход из Niri (с подтверждением) |
| `Mod+Shift+P` | Выключить мониторы |

### Окна и колонки

| Клавиши | Действие |
| --- | --- |
| `Mod+←/↓/↑/→` или `Mod+H/J/K/L` | Фокус на колонку/окно |
| `Mod+Ctrl+стрелки` или `Mod+Ctrl+H/J/K/L` | Переместить колонку/окно |
| `Mod+Shift+стрелки` или `Mod+Shift+H/J/K/L` | Фокус на монитор |
| `Mod+Ctrl+Shift+стрелки` | Переместить колонку на другой монитор |
| `Mod+R` / `Mod+Shift+R` | Следующая / предыдущая ширина колонки |
| `Mod+Ctrl+R` / `Mod+Ctrl+Shift+R` | Сброс / перебор высоты окна |
| `Mod+Minus` / `Mod+Equal` | Уже / шире колонка (−10 % / +10 %) |
| `Mod+Shift+Minus` / `Mod+Shift+Equal` | Ниже / выше окно |
| `Mod+F` | Плавающий режим |
| `Mod+Shift+V` | Переключение фокуса плавающие ↔ тайловые |
| `Mod+Shift+F` | Полный экран |
| `Mod+X` / `Mod+M` | Развернуть колонку / окно до краёв |
| `Mod+C` / `Mod+Ctrl+C` | Центрировать колонку / все видимые колонки |
| `Mod+W` | Режим вкладок в колонке |
| `Mod+[` / `Mod+]` | Забрать/выставить окно влево/вправо |
| `Mod+,` / `Mod+.` | Забрать окно в колонку / выставить из колонки |
| `Mod+Home` / `Mod+End` | Фокус на первую / последнюю колонку |
| `Mod+Ctrl+Home` / `Mod+Ctrl+End` | Переместить колонку в начало / конец |

### Рабочие столы

| Клавиши | Действие |
| --- | --- |
| `Mod+1…9` | Перейти на рабочий стол 1–9 |
| `Mod+Ctrl+1…9` | Переместить колонку на стол 1–9 |
| `Mod+Page_Down` / `Mod+Page_Up`, `Mod+U` / `Mod+I` | Следующий / предыдущий стол |
| `Mod+Shift+Page_Down` / `Mod+Shift+Page_Up`, `Mod+Shift+U` / `Mod+Shift+I` | Переместить стол вниз / вверх |
| `Mod+Ctrl+Page_Down` / `Mod+Ctrl+Page_Up` | Переместить колонку на следующий / предыдущий стол |
| `Mod+колесо` (вертикально) | Переключение рабочих столов |
| `Mod+Shift+колесо` | Фокус между колонками |

### Медиа и клавиши оборудования

| Клавиши | Действие |
| --- | --- |
| Громкость +/−/mute | `wpctl` через `scripts/osd.sh`, OSD: `swayosd` → `mako` |
| Mute микрофона | `osd.sh mic-mute` |
| Яркость +/− | `brightnessctl` через `osd.sh` (нужно правило sudoers) |
| Play / pause / stop / предыдущий / следующий | `playerctl` |
| `Print`, `Ctrl+Print`, `Alt+Print` | Штатные скриншоты Niri |

## Смена темы

В FlowNiri **15 палитр**. Тема — один файл `~/.config/themes/<id>.theme`;
переключатель заменяет цвета в `waybar/style.css`, `fuzzel/fuzzel.ini` и
`niri/config.kdl`.

| ID | Название |
| --- | --- |
| `ayu-dark` | Ayu Dark |
| `catppuccin-macchiato` | Catppuccin Macchiato |
| `catppuccin-mocha` | Catppuccin Mocha |
| `dracula` | Dracula |
| `everforest` | Everforest |
| `gruvbox-dark` | Gruvbox Dark |
| `gruvbox-light` | Gruvbox Light |
| `gruvbox-material` | Gruvbox Material |
| `kanagawa` | Kanagawa |
| `monochrome` | Монохром |
| `nord` | Nord |
| `one-dark` | One Dark |
| `rose-pine` | Rose Pine |
| `solarized-dark` | Solarized Dark |
| `tokyonight` | Tokyo Night |

**Через GUI:** `Mod+Shift+M` → **Темы** → выбрать палитру. Панель, лаунчер,
рамки окон и диалоги меняются сразу, Waybar перезапускается автоматически.
Классическое меню Zenity («Меню FlowNiri → Сменить тему») делает то же самое.

**Через терминал:**

```bash
~/.config/scripts/theme-switcher.sh --list          # список id
~/.config/scripts/theme-switcher.sh monochrome      # применить
~/.config/scripts/theme-switcher.sh --silent nord   # без уведомления
~/.config/scripts/apply_theme-switcher.sh           # переприменить GTK light/dark
~/.config/scripts/apply_theme-switcher.sh --mode light gruvbox-light
```

**Как это работает и почему безопасно:**

- У каждого ключа палитры (`BG`, `FG`, `ACCENT`, `RED`, …) внутри темы
  **уникальный** hex-цвет; перед изменениями тема проверяется на полноту.
- Цвета меняются через временные метки (`__FN0__`, `__FN1__`, …), поэтому две
  темы с одинаковым цветом не «каскадируют» друг в друга.
- Сначала создаётся снимок затронутых файлов в
  `~/.cache/flow-niri/backup/<время>/`.
- После замены выполняется `niri validate`. При ошибке все файлы
  восстанавливаются, сессия **не** перезагружается, а ошибка пишется в
  `~/.cache/flow-niri/last_error.log`.
- Перекрашивается только палитра FlowNiri. GTK-приложения остаются на
  стандартных **Adwaita / Adwaita-dark** (управляет
  `apply_theme-switcher.sh`: режим определяется по `MODE=`, имени темы или
  яркости `BG`). Это сделано специально — глобальная перекраска libadwaita
  ломала Nautilus и Firefox.

**Своя тема:** скопируйте существующий файл, оставьте все ключи, меняйте только
значения:

```bash
cp ~/.config/themes/monochrome.theme ~/.config/themes/my-theme.theme
$EDITOR ~/.config/themes/my-theme.theme
~/.config/scripts/theme-switcher.sh --list
```

Обязательные ключи: `BG BG_HARD BG_SOFT BG_SEL BORDER FG FG_STRONG FG_DIM GRAY
MUTED ACCENT ACCENT_2 RED RED_BRIGHT GREEN GREEN_BRIGHT BLUE PURPLE ORANGE`.
Необязательные: `NAME_EN`, `NAME_RU`, `MODE=light|dark`. Без `#` перед hex и без
повторов значений внутри одной темы.

## Waybar

`waybar/config.jsonc` — одна строка:

- **Слева:** `niri/workspaces`
- **Центр:** `niri/window`
- **Справа:** `niri/language`, `network`, `pulseaudio`, `cpu`, `memory`,
  `battery`, `clock`, `tray`, `custom/power`, `custom/ai-status`

| Модуль | Клик |
| --- | --- |
| Раскладка | `niri msg action switch-layout next` |
| Сеть | `nm-connection-editor` |
| Звук | `pavucontrol` |
| CPU / RAM | `btop` в Alacritty |
| Батарея | отчёт `upower` |
| Часы | `gsimplecal` |
| Питание | `scripts/power_menu.sh` |
| ИИ | `scripts/ai-launcher.sh` |

Модули включаются и выключаются в **Настройки → Панель** или в
«Меню FlowNiri → Настроить Waybar». Порядок хранится в
`~/.config/FlowNiri/waybar-order.conf`, поэтому выключенный модуль возвращается
на своё место. После изменений перезапускается только панель, не сессия.

## Мониторинг ИИ-агентов

| ID | Агент | Локальные данные |
| --- | --- | --- |
| `opencode` | OpenCode | `~/.local/share/opencode` (`opencode.db`) или `~/.opencode` |
| `claude` | Claude Code | `~/.claude` / `~/.config/claude`, `*.jsonl` |
| `codex` | Codex | `~/.codex` / `~/.config/codex`, сессии `*.jsonl` |
| `kimi` | Kimi Code | `~/.kimi`, `~/.moonshot`, `~/.config/kimi` |
| `freebuff` | Freebuff | `~/.freebuff`, `~/.config/freebuff`, `~/.local/share/freebuff` |

**Определение состояния** гибридное: проверка процесса
(`pgrep -u $USER -f <агент>`) плюс реальная активность (недавно изменённые файлы
в каталоге данных агента).

| Состояние | Значение |
| --- | --- |
| `active` | Процесс работает, данные менялись последние 5 минут |
| `idle` | Процесс работает, но молчит, либо данные менялись последние 2 минуты |
| `absent` | Процесса нет и активности нет |

| Unit | Интервал | Назначение |
| --- | --- | --- |
| `flow-niri-ai-active.timer` | каждые 30 с | Агент запущен — данные обновляются часто |
| `flow-niri-ai-idle.timer` | тик 5 мин, гейт 15 мин | Ничего не запущено — опрос редкий |

```bash
systemctl --user status flow-niri-ai-active.timer flow-niri-ai-idle.timer
systemctl --user list-timers 'flow-niri-ai-*'
```

Кэш — `~/.cache/flow-niri/ai-usage.json`; запись атомарная и под блокировкой,
поэтому модуль Waybar (читает раз в 30 с) никогда не блокируется и не запускает
тяжёлых процессов.

**Настройки — `~/.config/FlowNiri/ai.conf`** (права `600`, обновления его
**не перезаписывают**):

| Ключ | Значение |
| --- | --- |
| `ENABLED=1\|0` | Главный выключатель (или «Настройки → ИИ-агенты») |
| `AGENTS=a,b,c` | Каких агентов отслеживать |
| `LIMIT_<ID>=<токены>` | Бюджет агента на 5-часовое окно; `0` отключает процент |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `MOONSHOT_API_KEY` | Необязательные ключи для данных от провайдера |
| `ANTHROPIC_USAGE_URL`, `OPENAI_USAGE_URL` | Необязательные endpoint'ы (`curl --max-time 5`) |

Процент показывается только если он реальный: его сообщает провайдер либо
локальный счётчик токенов сравнивается с `LIMIT_<ID>`. Иначе модуль показывает
`—`, а не выдуманное число.

```bash
~/.config/scripts/ai-status.sh --refresh     # собрать сейчас
~/.config/scripts/ai-status.sh --waybar      # JSON для Waybar
~/.config/scripts/ai-status.sh --details     # отчёт для человека
~/.config/scripts/ai-launcher.sh             # окно статуса (Mod+Shift+A)
```

То же есть в **Настройках → ИИ-агенты** (включение, агенты, бюджеты, ключи,
«Обновить сейчас») и в меню Zenity. Данные никуда не отправляются, если вы сами
не настроили один из необязательных URL.

## Управление обоями

`scripts/wallpaper.sh` — единый бэкенд для GUI и CLI.

```bash
~/.config/scripts/wallpaper.sh get                  # "<путь>|<режим>"
~/.config/scripts/wallpaper.sh list                 # подходящие изображения
~/.config/scripts/wallpaper.sh modes                # fill fit stretch center tile
~/.config/scripts/wallpaper.sh set ~/Pictures/a.jpg fill
```

- **GUI:** `Mod+Shift+W` — Настройки → Обои; «Меню FlowNiri → Сменить обои» —
  то же самое с выбором файла.
- Меняется только строка `spawn-at-startup "swaybg" …` в `niri/config.kdl`.
  Весь конфиг проверяется, при ошибке восстанавливается.
- Обои применяются **сразу**, через `niri msg action spawn` — сессию
  перезапускать не нужно.
- Файл и режим запоминаются в `~/.config/FlowNiri/wallpaper.conf`.
- Режимы: `fill`, `fit`, `stretch`, `center`, `tile`.
- В репозитории есть `wallpapers/wallpaper.jpg`; установщик копирует его в
  `~/Downloads/wallpaper.jpg`, если файла ещё нет.

## Обновление и откат

FlowNiri обновляется из GitHub-релизов
[`SnowyFedora/FlowNiri`](https://github.com/SnowyFedora/FlowNiri) через GitHub
CLI. Один раз нужен `gh auth login`; запросов к API через `curl` нет.

**Модель релиза**

- Релиз — тег `vX.Y.Z` с одним ассетом `FlowNiri-X.Y.Z.zip`.
- В архиве **верхняя папка `FlowNiri/`**:

  ```text
  FlowNiri/
  ├── install.sh
  ├── README.md
  ├── niri/config.kdl
  ├── scripts/…
  ├── themes/…
  └── FlowNiri/            # ядро оболочки (manifest, i18n, UI, lib)
      ├── manifest.txt
      └── .version
  ```

- Установленная версия — `~/.config/FlowNiri/.version`.
- `FlowNiri/manifest.txt` перечисляет файлы, которыми владеет FlowNiri.
  Заменяются **только они**. Файлы состояния — `theme.name`, `lang.conf`,
  `ai.conf` — не перезаписываются никогда.
- Автоматические архивы GitHub «Source code» отклоняются: в них нет папки
  `FlowNiri/`.

**Обновление оболочки** («Настройки → Обновления → Обновить оболочку» или
«Меню FlowNiri → Обновить оболочку», `scripts/update.sh`):

1. Получает последний тег через `gh release list` и сравнивает с `.version`.
2. Запрашивает подтверждение, если есть новая версия.
3. Скачивает ZIP через `gh release download` во временный каталог.
4. Проверяет архив и структуру `FlowNiri/`.
5. Бэкапит все файлы из манифеста в
   `~/.cache/flow-niri/backup/<время>/`.
6. Копирует файлы манифеста в `~/.config/`, сохраняет права на запуск скриптов
   и заменяет домашний путь в ярлыках.
7. Обновляет `.version`, выполняет `niri validate`, перезапускает Waybar.
8. Проверяет `FlowNiri/packages.txt` и **сообщает**, каких пакетов не хватает —
   `pacman` с `sudo` не запускается, сессия не завершается.

Если валидация не прошла, всё восстанавливается из бэкапа, композитор не
перезагружается, ошибка пишется в `~/.cache/flow-niri/last_error.log`.

**Откат** («Настройки → Обновления → Откатить версию» или «Меню FlowNiri →
Откат версий», `scripts/rollback.sh`):

1. Показывает все теги релизов (новые сверху, текущий отмечен).
2. Скачивает и проверяет выбранный релиз.
3. Применяет ту же цепочку «бэкап → замена → проверка», что и обновление, и
   записывает версию тега в `.version`.

Откатываются только файлы FlowNiri. Пакеты автоматически не понижаются.

**Обновление системы** («Меню FlowNiri → Обновить систему»,
`scripts/system-update.sh`) — другая операция:

1. Создаёт архив `~/.config` в `~/Backups/`.
2. Запускает `pacman -Syu` в окне терминала.
3. Выполняет проверку целостности `pacman -Dk`.
4. Чистит кеш пакетов через `paccache`.
5. При ошибке предлагает восстановить `~/.config` из архива.

Откат пакетов невозможен — восстанавливаются только конфиги. Лог:
`~/.cache/flow-niri/last-system-update.log`.

**Сборка релиза (для автора):**

```bash
cd ~/FlowNiri
./release.sh --version 1.1.0 --notes "Что изменилось"
./release.sh --dry-run --version 1.1.0     # только собрать ZIP
```

`release.sh` упаковывает всё дерево (кроме `.git`, старых ZIP и `__pycache__`) в
`FlowNiri-<версия>.zip` с корнем `FlowNiri/`, проверяет структуру, делает
коммит, создаёт и пушит тег, публикует релиз с архивом. Источник по умолчанию —
`~/FlowNiri`, переопределяется через `FLOWNIRI_SRC`.

**Бэкапы и логи**

| Путь | Содержимое |
| --- | --- |
| `~/.cache/flow-niri/backup/<время>/` | Файлы манифеста перед обновлением/откатом/сменой темы |
| `~/.cache/flow-niri/install-backup/<время>/` | Конфиги, заменённые `install.sh` |
| `~/.cache/flow-niri/last_error.log` | Последняя ошибка `niri validate` |
| `~/.cache/flow-niri/flow.log` | Журнал действий |
| `~/.cache/flow-niri/ai-usage.json` | Кэш ИИ-монитора |
| `~/Backups/` | Архивы `~/.config` из обновления системы |

## Центр настроек

`Mod+Shift+M` открывает `FlowNiri/ui/settings.py` — окно GTK4 с боковой панелью:

| Страница | Содержимое |
| --- | --- |
| Темы | 15 палитр, текущая подсвечена |
| Обои | Выбор файла и режим |
| Окна | Скругление углов (0 или 12) |
| Панель | Включение модулей Waybar, перезапуск панели |
| Клавиши | Список горячих клавиш, открытие `config.kdl` |
| Блокировка | Таймеры блокировки и сна (`idle.sh`) |
| Приложения | Браузер, файловый менеджер, редактор по умолчанию |
| ИИ | Мониторинг, агенты, бюджеты, ключи, живой статус |
| Обновления | Обновить оболочку, откатить версию |
| Очистка | Безопасное удаление устаревших файлов |
| Язык | English / Русский |
| О программе | Версия, репозиторий, пути |

Если PyGObject/GTK4 нет, `flowniri-settings.sh` прозрачно откроет меню Zenity
(`flowniri-menu.sh`). Те же действия доступны без GUI через
`flowniri-cli.sh`:

```bash
~/.config/scripts/flowniri-cli.sh status
~/.config/scripts/flowniri-cli.sh radius 12
~/.config/scripts/flowniri-cli.sh idle 5 15
~/.config/scripts/flowniri-cli.sh lang ru
~/.config/scripts/flowniri-cli.sh waybar-toggle network
~/.config/scripts/flowniri-cli.sh ai-toggle 1
~/.config/scripts/flowniri-cli.sh hotkeys
```

## Язык интерфейса

- Строки интерфейса: `~/.config/FlowNiri/i18n/en.conf` и `ru.conf`.
- Активный язык: `LANG=ru|en` в `~/.config/FlowNiri/lang.conf`.
- Переключение: **Настройки → Язык**, меню Zenity или
  `flowniri-cli.sh lang ru`.
- Оверлей клавиш (`Mod+/`) формируется на активном языке; штатный оверлей Niri —
  на английском.

## Очистка

`scripts/cleanup.sh` («Настройки → Очистка» или «Меню FlowNiri → Очистка старых
файлов») собирает список кандидатов — ярлыки старых установщиков и скрипты
FlowNiri, которые больше нигде не вызываются, — показывает его с флажками и
удаляет **только** отмеченное. Автоматически ничего не удаляется, пакеты,
зависимости и системные файлы не затрагиваются.

## Решение проблем

| Симптом | Решение |
| --- | --- |
| Центр настроек не открывается | `python3 -c 'import gi; gi.require_version("Gtk","4.0")'` — поставьте `python-gobject gtk4` или используйте `flowniri-menu.sh` |
| «Не удалось связаться с GitHub» | `gh auth login`, затем повторите |
| Обновление пишет, что архив битый | В релизе нет папки `FlowNiri/` — берите ZIP проекта, а не архив исходников GitHub |
| Niri не принял конфиг | Смотрите `~/.cache/flow-niri/last_error.log`, старые файлы — в `~/.cache/flow-niri/backup/` |
| Пропала панель | `env -u GTK_THEME waybar &` или «Настройки → Панель → Перезапустить панель» |
| ИИ показывает `—` / `N/A` | Агент не запущен, нет локальных данных или `LIMIT_<ID>=0`; проверьте `ai.conf` и `ai-status.sh --details` |
| Не работают клавиши яркости | Добавьте правило sudoers для `brightnessctl` (раздел «Установка») |
| GTK-приложения выглядят как Adwaita | Так и задумано: палитра FlowNiri — только Niri/Waybar/Fuzzel |
| Таймеры не работают | `systemctl --user enable --now flow-niri-ai-active.timer flow-niri-ai-idle.timer` |
| Пути ведут на другого пользователя | `grep -rl /home/vladikusb ~/.config` и замените на свой `$HOME` |

## Удаление

```bash
systemctl --user disable --now flow-niri-ai-active.timer flow-niri-ai-idle.timer
rm -rf ~/.config/{FlowNiri,themes,scripts,niri,waybar,fuzzel,alacritty,btop,mako,gtklock,qt6ct,xdg-desktop-portal}
rm -rf ~/.local/share/applications/flowniri-*.desktop
rm -rf ~/.cache/flow-niri
# опционально: ~/.zshrc, ~/Downloads/Wallpapers, ~/.config/gtk-3.0, ~/.config/gtk-4.0
```

Пакеты автоматически не удаляются; при необходимости используйте
`pacman -Rns`.

## Благодарности

- [Niri](https://github.com/YaLTeR/niri) — прокручиваемый тайловый композитор Wayland
- [Waybar](https://github.com/Alexays/Waybar), [Fuzzel](https://codeberg.org/dnkl/fuzzel), [Alacritty](https://github.com/alacritty/alacritty)
- [Catppuccin](https://github.com/catppuccin), [Gruvbox](https://github.com/morhetz/gruvbox), [Dracula](https://draculatheme.com), [Nord](https://www.nordtheme.com), [Tokyo Night](https://github.com/folke/tokyonight.nvim) и другие палитры
- Автор: **VladikUSB** / [SnowyFedora](https://github.com/SnowyFedora)

Файл лицензии пока не добавлен; до его появления считайте репозиторий личными
дотфайлами автора.
