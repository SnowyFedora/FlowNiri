#!/usr/bin/env python3
# ============================================================
#  FlowNiri Settings — GTK4 control centre
#
#  Palette comes from ~/.config/themes/<id>.theme.
#  The same application drives:
#    * the GTK3/GTK4/Qt theme  (scripts/apply_theme-switcher.sh)
#    * the niri/waybar palette (scripts/theme-switcher.sh)
#
#  Every signal handler takes *args: GTK passes the emitting widget to
#  "clicked", so a handler declared without it fails on Python 3.12+
#  with "takes 1 positional argument but 2 were given".
# ============================================================
import json
import os
import re
import subprocess
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, Gio, GLib, Gtk, Pango  # noqa: E402

HOME = os.path.expanduser("~")
CONF = os.path.join(HOME, ".config")
FLOW = os.path.join(CONF, "FlowNiri")
UI_DIR = os.path.join(FLOW, "ui")
SCRIPTS = os.path.join(CONF, "scripts")
CLI = os.path.join(SCRIPTS, "flowniri-cli.sh")
WALLPAPER = os.path.join(SCRIPTS, "wallpaper.sh")
THEME_SWITCHER = os.path.join(SCRIPTS, "theme-switcher.sh")
GLOBAL_THEME = os.path.join(SCRIPTS, "apply_theme-switcher.sh")
THEMES_DIR = os.path.join(CONF, "themes")
KDL = os.path.join(CONF, "niri", "config.kdl")
AI_CONF = os.path.join(FLOW, "ai.conf")
VERSION_FILE = os.path.join(FLOW, ".version")
THEME_NAME_FILE = os.path.join(FLOW, "theme.name")
CACHE_DIR = os.path.join(HOME, ".cache", "flow-niri")
REPO_URL = "https://github.com/SnowyFedora/FlowNiri"

PALETTE = [
    "BG", "BG_HARD", "BG_SOFT", "BG_SEL", "BORDER", "FG", "FG_STRONG",
    "FG_DIM", "GRAY", "MUTED", "ACCENT", "ACCENT_2", "RED", "RED_BRIGHT",
    "GREEN", "GREEN_BRIGHT", "BLUE", "PURPLE", "ORANGE",
]
SWATCH_KEYS = ["BG", "BG_SOFT", "FG_DIM", "FG", "ACCENT", "ACCENT_2", "RED", "GREEN", "BLUE"]
WALL_MODES = ["fill", "fit", "stretch", "center", "tile"]
AGENT_IDS = ["opencode", "freebuff", "claude", "codex", "kimi"]
KEY_FIELDS = [
    ("ANTHROPIC_API_KEY", "ai_key_anthropic"),
    ("OPENAI_API_KEY", "ai_key_openai"),
    ("MOONSHOT_API_KEY", "ai_key_moonshot"),
]

LIGHT_HINTS = ("light", "white", "day", "светл", "бел")
DARK_HINTS = ("dark", "night", "black", "midnight", "темн", "тёмн", "черн", "чёрн")

L = {
    "ru": {
        "title": "Настройки FlowNiri", "app_sub": "оболочка рабочего стола",
        "sec_look": "ВНЕШНИЙ ВИД", "sec_desk": "РАБОЧИЙ СТОЛ", "sec_sys": "СИСТЕМА",
        "themes": "Темы", "themes_sub": "Палитра панели, лаунчера и рамок окон.",
        "themes_hint": "Палитра применяется к Niri, Waybar и Fuzzel. GTK-приложения "
                       "(Zenity, Nautilus, Firefox) остаются на стандартной Adwaita и "
                       "переключаются только светлым/тёмным режимом.",
        "active": "Активная тема", "open_folder": "Папка тем",
        "theme_ok": "Тема применена: {name}", "theme_fail": "Не удалось применить тему",
        "theme_current": "Эта тема уже активна",
        "system_mode": "Режим системы", "light_mode": "Светлая тема",
        "mode_hint": "Светлый режим включает color-scheme prefer-light и Adwaita для "
                     "всех GTK-приложений (Zenity, Nautilus, Firefox). Тёмный — prefer-dark "
                     "и Adwaita-dark. Палитра Niri, Waybar и Fuzzel не меняется.",
        "mode_light": "Светлый режим включён", "mode_dark": "Тёмный режим включён",
        "no_mode_theme": "Нет темы с таким режимом",
        "qt_restart": "Перезапустите Qt-приложения: {apps}",
        "wallpaper": "Обои",
        "wallpaper_sub": "Изображение рабочего стола и способ масштабирования.",
        "choose_image": "Выбрать изображение…", "images": "Изображения", "apply": "Применить",
        "mode_fill": "Заполнить", "mode_fit": "Вписать", "mode_stretch": "Растянуть",
        "mode_center": "По центру", "mode_tile": "Мозаика",
        "wp_ok": "Обои применены", "wp_fail": "Не удалось применить обои",
        "windows": "Окна", "windows_sub": "Скругление углов окон и всплывающих подсказок.",
        "radius_hint": "0 — прямые углы, 12 — значение по умолчанию.",
        "panel": "Панель", "panel_sub": "Модули справа.",
        "panel_restart": "Перезапустить панель", "panel_restarted": "Панель перезапущена",
        "keys": "Клавиши", "keys_sub": "Действующие сочетания из ~/.config/niri/config.kdl.",
        "refresh": "Обновить", "open_config": "Открыть конфиг",
        "lock": "Блокировка", "lock_sub": "gtklock включается по простою через swayidle.",
        "lock_after": "Блокировать через, мин", "sleep_after": "Сон через, мин",
        "save": "Сохранить", "saved": "Сохранено",
        "apps": "Приложения", "apps_sub": "Обработчики по умолчанию.",
        "browser": "Браузер", "filemanager": "Файловый менеджер", "editor": "Редактор",
        "apps_hint": "Идентификатор .desktop без расширения.",
        "ai": "ИИ-агенты", "ai_sub": "Состояние агентов, проценты лимитов и API-ключи.",
        "ai_enable": "Мониторинг включён", "ai_agents": "Какие агенты отслеживать",
        "ai_budget": "Бюджет токенов (5 ч)",
        "ai_budget_hint": "Процент считается как локальный расход за 5 часов к этому бюджету.",
        "ai_keys": "API-ключи", "ai_key_anthropic": "Anthropic (Claude Code)",
        "ai_key_openai": "OpenAI (Codex)", "ai_key_moonshot": "Moonshot (Kimi Code)",
        "ai_keep": "оставь пустым, чтобы не менять", "ai_refresh": "Обновить сейчас",
        "ai_updated": "Данные агентов обновлены", "ai_state_active": "активен",
        "ai_state_idle": "простой", "ai_state_absent": "не установлен",
        "ai_no_percent": "нет данных",
        "updates": "Обновления",
        "updates_sub": "Обновление оболочки, откат версии и системные пакеты.",
        "update_now": "Обновить FlowNiri", "rollback": "Откатить версию",
        "system_update": "Обновить систему", "check_cfg": "Проверить конфиг niri",
        "cfg_ok": "Конфиг валиден", "cfg_fail": "Конфиг с ошибкой",
        "launched": "Запущено в отдельном окне", "cleanup": "Очистка",
        "cleanup_sub": "Старые ярлыки и скрипты. Файлы не удаляются — они уезжают в архив.",
        "cleanup_none": "Старых ярлыков и скриптов не найдено",
        "cleanup_btn": "В архив", "cleanup_confirm": "Переместить выбранное в архив?",
        "cleanup_done": "Перемещено файлов: {n}", "language": "Язык",
        "language_sub": "Язык меню, диалогов и этого окна.",
        "lang_restart": "Перезапустить настройки",
        "about": "О системе", "about_sub": "Версии, тема и пути конфигурации.",
        "version": "Версия FlowNiri", "niri_version": "Niri", "waybar_version": "Waybar",
        "theme": "Тема", "config_path": "Конфиг", "cache_path": "Кэш",
        "repo": "Репозиторий", "cancel": "Отмена", "close": "Закрыть",
        "missing": "Нет скрипта: {name}",
    },
    "en": {
        "title": "FlowNiri Settings", "app_sub": "desktop shell",
        "sec_look": "APPEARANCE", "sec_desk": "DESKTOP", "sec_sys": "SYSTEM",
        "themes": "Themes", "themes_sub": "Palette for the bar, launcher and window borders.",
        "themes_hint": "The palette applies to Niri, Waybar and Fuzzel. GTK apps "
                       "(Zenity, Nautilus, Firefox) keep standard Adwaita and only "
                       "follow the light/dark switch.",
        "active": "Active theme", "open_folder": "Theme folder",
        "theme_ok": "Theme applied: {name}", "theme_fail": "Could not apply the theme",
        "theme_current": "That theme is already active",
        "system_mode": "System mode", "light_mode": "Light theme",
        "mode_hint": "Light mode sets color-scheme prefer-light and Adwaita for every "
                     "GTK app (Zenity, Nautilus, Firefox). Dark sets prefer-dark and "
                     "Adwaita-dark. The Niri, Waybar and Fuzzel palette is untouched.",
        "mode_light": "Light mode enabled", "mode_dark": "Dark mode enabled",
        "no_mode_theme": "No theme with that mode",
        "qt_restart": "Restart Qt apps: {apps}",
        "wallpaper": "Wallpaper",
        "wallpaper_sub": "Desktop image and how it is scaled.",
        "choose_image": "Choose image…", "images": "Images", "apply": "Apply",
        "mode_fill": "Fill", "mode_fit": "Fit", "mode_stretch": "Stretch",
        "mode_center": "Center", "mode_tile": "Tile",
        "wp_ok": "Wallpaper applied", "wp_fail": "Could not apply the wallpaper",
        "windows": "Windows", "windows_sub": "Corner rounding for windows and popups.",
        "radius_hint": "0 is square, 12 is the default.",
        "panel": "Panel", "panel_sub": "Right-side modules.",
        "panel_restart": "Restart panel", "panel_restarted": "Panel restarted",
        "keys": "Shortcuts", "keys_sub": "Active bindings from ~/.config/niri/config.kdl.",
        "refresh": "Refresh", "open_config": "Open config",
        "lock": "Lock screen", "lock_sub": "gtklock runs on idle through swayidle.",
        "lock_after": "Lock after, min", "sleep_after": "Suspend after, min",
        "save": "Save", "saved": "Saved",
        "apps": "Applications", "apps_sub": "Default handlers.",
        "browser": "Browser", "filemanager": "File manager", "editor": "Editor",
        "apps_hint": "A .desktop id without the extension.",
        "ai": "AI agents", "ai_sub": "Agent state, limit percentages and API keys.",
        "ai_enable": "Monitoring enabled", "ai_agents": "Agents to watch",
        "ai_budget": "Token budget (5 h)",
        "ai_budget_hint": "The percentage is local usage over the last 5 hours against this budget.",
        "ai_keys": "API keys", "ai_key_anthropic": "Anthropic (Claude Code)",
        "ai_key_openai": "OpenAI (Codex)", "ai_key_moonshot": "Moonshot (Kimi Code)",
        "ai_keep": "leave empty to keep", "ai_refresh": "Refresh now",
        "ai_updated": "Agent data refreshed", "ai_state_active": "active",
        "ai_state_idle": "idle", "ai_state_absent": "not installed",
        "ai_no_percent": "no data",
        "updates": "Updates",
        "updates_sub": "Shell updates, version rollback and system packages.",
        "update_now": "Update FlowNiri", "rollback": "Roll back version",
        "system_update": "Update system", "check_cfg": "Validate niri config",
        "cfg_ok": "Config is valid", "cfg_fail": "Config has an error",
        "launched": "Started in its own window", "cleanup": "Cleanup",
        "cleanup_sub": "Old launchers and scripts. Nothing is deleted — files move to the archive.",
        "cleanup_none": "No old launchers or scripts found",
        "cleanup_btn": "Archive", "cleanup_confirm": "Move the selected files to the archive?",
        "cleanup_done": "Files moved: {n}", "language": "Language",
        "language_sub": "Language of the menu, dialogs and this window.",
        "lang_restart": "Restart settings",
        "about": "About", "about_sub": "Versions, theme and configuration paths.",
        "version": "FlowNiri version", "niri_version": "Niri", "waybar_version": "Waybar",
        "theme": "Theme", "config_path": "Config", "cache_path": "Cache",
        "repo": "Repository", "cancel": "Cancel", "close": "Close",
        "missing": "Missing script: {name}",
    },
}


# ------------------------------------------------------------ helpers ---
def sh(argv, timeout=45):
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout or "").strip(), (p.stderr or "").strip()
    except subprocess.TimeoutExpired:
        return 124, "", "timed out"
    except OSError as exc:
        return 127, "", str(exc)


def read_conf(path):
    data = {}
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, val = line.split("=", 1)
                val = val.strip()
                if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
                    val = val[1:-1]
                data[key.strip()] = val
    except OSError:
        pass
    return data


def parse_kv(text):
    data = {}
    for line in (text or "").splitlines():
        if "=" in line:
            key, val = line.split("=", 1)
            data[key.strip()] = val.strip()
    return data


def last_line(text):
    for line in reversed((text or "").splitlines()):
        if line.strip():
            return line.strip()
    return ""


def theme_ids():
    try:
        return sorted(f[:-6] for f in os.listdir(THEMES_DIR) if f.endswith(".theme"))
    except OSError:
        return []


def theme_data(tid):
    if not tid:
        return {}
    return read_conf(os.path.join(THEMES_DIR, tid + ".theme"))


def clean_color(value):
    if not value:
        return "#000000"
    value = value.strip().strip("\"'")
    if re.match(r"^#[0-9a-fA-F]{3,8}$", value):
        return value
    if re.match(r"^[0-9a-fA-F]{3,8}$", value):
        return "#" + value
    return value


def color_luma(value):
    hexval = clean_color(value).lstrip("#")
    if len(hexval) == 3:
        hexval = "".join(ch * 2 for ch in hexval)
    if len(hexval) < 6:
        return 0
    try:
        red = int(hexval[0:2], 16)
        green = int(hexval[2:4], 16)
        blue = int(hexval[4:6], 16)
    except ValueError:
        return 0
    return (red * 299 + green * 587 + blue * 114) // 1000


def theme_mode(tid, data=None):
    """light|dark from MODE=, then the id, then the luminance of BG."""
    data = data if data is not None else theme_data(tid)
    raw = (data.get("MODE") or "").strip().lower()
    if raw:
        if any(hint in raw for hint in LIGHT_HINTS):
            return "light"
        if any(hint in raw for hint in DARK_HINTS):
            return "dark"
    lower = (tid or "").lower()
    if any(hint in lower for hint in LIGHT_HINTS):
        return "light"
    if any(hint in lower for hint in DARK_HINTS):
        return "dark"
    return "light" if color_luma(data.get("BG")) >= 128 else "dark"


def set_gtk_dark_preference(dark):
    """GTK 4.20+ prefers gtk-interface-color-scheme; older versions only
    understand gtk-application-prefer-dark-theme."""
    settings = Gtk.Settings.get_default()
    if settings is None:
        return
    if settings.find_property("gtk-interface-color-scheme") is not None:
        try:
            scheme = (Gtk.InterfaceColorScheme.DARK if dark
                      else Gtk.InterfaceColorScheme.LIGHT)
            settings.set_property("gtk-interface-color-scheme", scheme)
            return
        except (TypeError, AttributeError):
            pass
    try:
        settings.set_property("gtk-application-prefer-dark-theme", dark)
    except (TypeError, AttributeError):
        pass


def current_theme_id():
    try:
        with open(THEME_NAME_FILE, encoding="utf-8") as fh:
            name = fh.readline().strip()
            if name:
                return name
    except OSError:
        pass
    return "gruvbox-dark"


def build_css(tid):
    """Palette + settings.css. Written to the cache for debugging."""
    current = theme_data(tid)
    fallback = theme_data("gruvbox-dark")
    lines = ["/* FlowNiri settings — generated from %s */" % (tid or "fallback")]
    for key in PALETTE:
        value = clean_color(current.get(key) or fallback.get(key) or "000000")
        lines.append("@define-color %s %s;" % (key.lower(), value))

    # Colour swatches for every theme card (class names carry the hex value).
    rules = set()
    for other in theme_ids():
        data = theme_data(other)
        for key in SWATCH_KEYS:
            colour = clean_color(data.get(key))
            rules.add(".chip-%s { background-color: %s; }" % (colour.lstrip("#"), colour))
    lines.append("\n".join(sorted(rules)))

    try:
        with open(os.path.join(UI_DIR, "settings.css"), encoding="utf-8") as fh:
            lines.append(fh.read())
    except OSError:
        pass

    css = "\n".join(lines)
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(os.path.join(CACHE_DIR, "settings.css"), "w", encoding="utf-8") as fh:
            fh.write(css)
    except OSError:
        pass
    return css


def label(text, cls=None, wrap=False):
    widget = Gtk.Label(label=text)
    widget.set_xalign(0.0)
    widget.set_halign(Gtk.Align.START)
    if wrap:
        widget.set_wrap(True)
        widget.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
    if cls:
        widget.add_css_class(cls)
    return widget


def hrow(*children, spacing=12):
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=spacing)
    for child in children:
        if child is not None:
            box.append(child)
    return box


def vbox(*children, spacing=10):
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=spacing)
    for child in children:
        if child is not None:
            box.append(child)
    return box


def card(*children, spacing=10):
    box = vbox(*children, spacing=spacing)
    box.add_css_class("card")
    return box


def heading(title, sub):
    box = vbox(spacing=4)
    box.append(label(title, "h1"))
    if sub:
        box.append(label(sub, "sub", wrap=True))
    box.set_margin_bottom(4)
    return box


def scrolled_page():
    win = Gtk.ScrolledWindow()
    win.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    win.set_hexpand(True)
    win.set_vexpand(True)
    body = vbox(spacing=14)
    body.add_css_class("page")
    win.set_child(body)
    return win, body


def value_row(text_widget, control):
    box = hrow(spacing=12)
    box.add_css_class("row")
    text_widget.set_hexpand(True)
    box.append(text_widget)
    if control is not None:
        box.append(control)
    return box


class SettingsWindow(Gtk.ApplicationWindow):
    NAV = [
        ("section", "sec_look", None),
        ("page", "themes", "appearance", "applications-graphics"),
        ("page", "wallpaper", "wallpaper", "preferences-desktop-wallpaper"),
        ("page", "windows", "windows", "preferences-desktop-display"),
        ("page", "panel", "panel", "preferences-desktop"),
        ("page", "keys", "keys", "input-keyboard"),
        ("section", "sec_desk", None),
        ("page", "lock", "lock", "system-lock-screen"),
        ("page", "apps", "apps", "applications-system"),
        ("page", "ai", "ai", "utilities-system-monitor"),
        ("section", "sec_sys", None),
        ("page", "updates", "updates", "system-software-update"),
        ("page", "cleanup", "cleanup", "user-trash"),
        ("page", "language", "language", "preferences-desktop-locale"),
        ("page", "about", "about", "help-about"),
    ]

    def __init__(self, app, start_page=None):
        super().__init__(application=app)
        self.set_default_size(1120, 760)
        self.set_size_request(900, 560)
        self.theme = current_theme_id()
        self.lang = self.current_lang()
        self.t = L[self.lang]
        self.info = self.status()
        self.pages = {}
        self.loading = True
        self.syncing = False
        self.toast_source = 0
        self.provider = None
        self.theme_cards = {}
        self.set_title(self.t["title"])
        self.sync_gtk_prefer_dark()
        self.build()
        self.loading = False
        self.select_page(start_page or "appearance")

    # --------------------------------------------------------- state ----
    @property
    def active_mode(self):
        return theme_mode(self.theme)

    def system_mode(self):
        """light|dark of org.gnome.desktop.interface color-scheme.

        This is what GTK apps actually use, so the switch reflects the
        system instead of the palette of the current theme."""
        rc, out, _ = sh(["gsettings", "get", "org.gnome.desktop.interface",
                         "color-scheme"], timeout=15)
        text = (out or "").lower()
        if "prefer-light" in text:
            return "light"
        if "prefer-dark" in text:
            return "dark"
        return self.active_mode

    def status(self):
        rc, out, _ = sh([CLI, "status"])
        return parse_kv(out)

    def current_lang(self):
        lang = read_conf(os.path.join(FLOW, "lang.conf")).get("LANG", "")
        return lang if lang in L else "ru"

    def theme_name(self, tid, data=None):
        data = data if data is not None else theme_data(tid)
        return data.get("NAME_" + self.lang.upper()) or data.get("NAME_EN") or tid

    @property
    def version(self):
        try:
            with open(VERSION_FILE, encoding="utf-8") as fh:
                return fh.readline().strip() or "?"
        except OSError:
            return "?"


    # ------------------------------------------------------------ ui ----
    def build(self):
        root = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.set_child(root)
        root.append(self.build_sidebar())

        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        right.set_hexpand(True)
        root.append(right)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(120)
        self.stack.set_hexpand(True)
        self.stack.set_vexpand(True)
        right.append(self.stack)
        right.append(self.build_footer())

        self.builders = {
            "appearance": self.page_appearance,
            "wallpaper": self.page_wallpaper,
            "windows": self.page_windows,
            "panel": self.page_panel,
            "keys": self.page_keys,
            "lock": self.page_lock,
            "apps": self.page_apps,
            "ai": self.page_ai,
            "updates": self.page_updates,
            "cleanup": self.page_cleanup,
            "language": self.page_language,
            "about": self.page_about,
        }

        self.reload_css()
        self.show_page("appearance")

    def build_sidebar(self):
        win = Gtk.ScrolledWindow()
        win.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        win.set_size_request(252, -1)
        win.add_css_class("sidebar")

        body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        brand = vbox(spacing=0)
        brand.set_margin_top(8)
        brand.append(label("FlowNiri", "brand"))
        brand.append(label(self.t["app_sub"], "brand-sub"))
        body.append(brand)

        self.nav = Gtk.ListBox()
        self.nav.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.nav.connect("row-selected", self.on_nav_selected)
        body.append(self.nav)

        for entry in self.NAV:
            kind, key = entry[0], entry[1]
            page_id = entry[2] if kind == "page" else None
            icon = entry[3] if kind == "page" else None
            row = Gtk.ListBoxRow()
            if kind == "section":
                row.set_selectable(False)
                row.set_activatable(False)
                row.set_child(label(self.t[key], "section"))
            else:
                box = hrow(spacing=10)
                image = Gtk.Image.new_from_icon_name(icon)
                image.set_pixel_size(16)
                box.append(image)
                box.append(label(self.t[key]))
                row.set_child(box)
                row.page_id = page_id
            self.nav.append(row)

        win.set_child(body)
        return win

    def build_footer(self):
        box = hrow(spacing=10)
        box.add_css_class("footer")
        self.footer_msg = label("", "dim")
        self.footer_msg.set_hexpand(True)
        box.append(self.footer_msg)
        box.append(label("FlowNiri %s" % self.version, "dim"))
        return box

    def on_nav_selected(self, _listbox, row, *args):
        page_id = getattr(row, "page_id", None) if row else None
        if page_id:
            self.show_page(page_id)

    def select_page(self, page_id):
        for row in self.nav.observe_children():
            if isinstance(row, Gtk.ListBoxRow) and getattr(row, "page_id", None) == page_id:
                self.nav.select_row(row)
                return
        self.show_page(page_id)

    def show_page(self, page_id):
        builder = self.builders.get(page_id)
        if builder is None:
            return
        if page_id not in self.pages:
            page = builder()
            self.pages[page_id] = page
            self.stack.add_named(page, page_id)
        self.stack.set_visible_child_name(page_id)

    def rebuild(self, page_id):
        old = self.pages.pop(page_id, None)
        if old is not None:
            self.stack.remove(old)
        self.show_page(page_id)

    def reload_css(self):
        css = build_css(self.theme)
        if self.provider is None:
            self.provider = Gtk.CssProvider()
            display = Gdk.Display.get_default()
            if display is not None:
                # Above PRIORITY_USER: GTK also loads ~/.config/gtk-4.0/gtk.css
                # for every GTK4 app, and that provider would otherwise
                # override the window's own palette and button colours.
                Gtk.StyleContext.add_provider_for_display(
                    display, self.provider, Gtk.STYLE_PROVIDER_PRIORITY_USER + 1)
        try:
            if hasattr(self.provider, "load_from_string"):
                self.provider.load_from_string(css)
            else:
                self.provider.load_from_data(css.encode("utf-8"))
        except GLib.Error as exc:
            print("FlowNiri: CSS error: %s" % exc.message, file=sys.stderr)

    def sync_gtk_prefer_dark(self):
        set_gtk_dark_preference(self.active_mode == "dark")

    def sync_mode_switch(self):
        switch = getattr(self, "mode_switch", None)
        if switch is None:
            return
        want = self.system_mode() == "light"
        if switch.get_active() == want:
            return
        self.syncing = True
        try:
            switch.set_active(want)
        finally:
            self.syncing = False

    def toast(self, message, ok=True):
        if not hasattr(self, "footer_msg"):
            return
        self.footer_msg.set_label(message)
        self.footer_msg.remove_css_class("ok")
        self.footer_msg.remove_css_class("err")
        self.footer_msg.add_css_class("ok" if ok else "err")
        if self.toast_source:
            GLib.source_remove(self.toast_source)
        self.toast_source = GLib.timeout_add(6000, self.clear_toast)

    def clear_toast(self, *args):
        self.toast_source = 0
        if hasattr(self, "footer_msg"):
            self.footer_msg.set_label("")
        return GLib.SOURCE_REMOVE

    def launch(self, script, *args):
        name = os.path.basename(script)
        if not os.path.exists(script):
            self.toast(self.t["missing"].format(name=name), ok=False)
            return
        try:
            subprocess.Popen([script, *args], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
            self.toast(self.t["launched"])
        except OSError as exc:
            self.toast(str(exc), ok=False)

    def restart_app(self, page_id="appearance"):
        try:
            subprocess.Popen([sys.executable, os.path.abspath(__file__), "--page", page_id],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
        except OSError:
            return
        app = self.get_application()
        if app is not None:
            app.quit()

    def open_path(self, path):
        sh(["xdg-open", path], timeout=10)

    # ------------------------------------------------------ appearance ---
    def page_appearance(self):
        win, body = scrolled_page()
        body.append(heading(self.t["themes"], self.t["themes_sub"]))

        mode_box = card(spacing=6)
        mode_box.append(label(self.t["system_mode"], "h2"))
        self.mode_switch = Gtk.Switch()
        self.mode_switch.set_valign(Gtk.Align.CENTER)
        self.mode_switch.set_active(self.system_mode() == "light")
        self.mode_switch.connect("state-set", self.on_mode_toggle)
        mode_box.append(value_row(label(self.t["light_mode"]), self.mode_switch))
        mode_box.append(label(self.t["mode_hint"], "dim", wrap=True))
        body.append(mode_box)

        self.theme_value = label(self.theme_name(self.theme), "value")
        self.theme_value.set_hexpand(True)
        folder = Gtk.Button(label=self.t["open_folder"])
        folder.connect("clicked", self.on_open_themes)
        body.append(card(value_row(
            hrow(label(self.t["active"]), self.theme_value, spacing=8), folder), spacing=6))

        flow = Gtk.FlowBox()
        flow.set_selection_mode(Gtk.SelectionMode.NONE)
        flow.set_column_spacing(10)
        flow.set_row_spacing(10)
        flow.set_max_children_per_line(4)
        flow.set_min_children_per_line(2)
        flow.set_homogeneous(True)
        flow.set_valign(Gtk.Align.START)
        self.theme_cards = {}
        for tid in theme_ids():
            flow.append(self.theme_card(tid))
        body.append(flow)
        body.append(label(self.t["themes_hint"], "sub", wrap=True))
        return win

    def theme_card(self, tid):
        data = theme_data(tid)
        button = Gtk.Button()
        button.add_css_class("theme-card")
        if tid == self.theme:
            button.add_css_class("active")
        inner = vbox(spacing=6)
        inner.append(self.swatch_strip(data))
        name = label(self.theme_name(tid, data), "theme-name")
        name.set_ellipsize(Pango.EllipsizeMode.END)
        inner.append(name)
        button.set_child(inner)
        button.set_tooltip_text(self.theme_name(tid, data))
        button.connect("clicked", self.on_theme_clicked, tid)
        self.theme_cards[tid] = button
        return button

    def swatch_strip(self, data):
        strip = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        strip.set_size_request(170, 42)
        last = len(SWATCH_KEYS) - 1
        for idx, key in enumerate(SWATCH_KEYS):
            colour = clean_color(data.get(key)).lstrip("#")
            chip = Gtk.Box()
            chip.add_css_class("chip")
            chip.add_css_class("chip-%s" % colour)
            if idx == 0:
                chip.add_css_class("chip-first")
            if idx == last:
                chip.add_css_class("chip-last")
            chip.set_hexpand(True)
            strip.append(chip)
        return strip

    def on_open_themes(self, *args):
        self.open_path(THEMES_DIR)

    def on_theme_clicked(self, _button, tid, *args):
        self.apply_theme(tid)

    def on_mode_toggle(self, switch, state, *args):
        # The switch is the system mode only: GTK apps get Adwaita(-dark)
        # through color-scheme. The niri/waybar/fuzzel palette belongs to the
        # theme cards and is deliberately not touched here.
        # Return True: the state is set by sync_mode_switch() once the mode
        # has actually been applied, so a failure never lies in the UI.
        if self.loading or self.syncing:
            return False
        self.set_system_mode("light" if state else "dark")
        return True

    def set_system_mode(self, mode):
        """Force color-scheme and Adwaita(-dark) without touching the palette."""
        rc, out, err = sh([GLOBAL_THEME, "--mode", mode, self.theme], timeout=90)
        if rc != 0:
            self.toast(last_line(err or out) or self.t["theme_fail"], ok=False)
        else:
            self.toast(self.t["mode_" + mode])
        GLib.idle_add(self.sync_mode_switch)

    def apply_theme(self, tid, mode=None):
        if tid not in theme_ids():
            self.toast(self.t["theme_fail"], ok=False)
            self.sync_mode_switch()
            return
        if tid == self.theme:
            self.toast(self.t["theme_current"])
            self.sync_mode_switch()
            return

        # 1. niri / waybar / fuzzel palette. --silent: no zenity notification.
        rc1, out1, err1 = sh([THEME_SWITCHER, "--silent", tid], timeout=90)

        # 2. color-scheme + Adwaita for GTK, Qt style. Runs last so it wins.
        #    The mode is explicit: the palette itself never reaches GTK apps.
        rc2, out2, err2 = sh([GLOBAL_THEME, "--mode", theme_mode(tid), tid], timeout=90)

        if rc1 != 0:
            self.toast(last_line(err1 or out1) or self.t["theme_fail"], ok=False)
            self.sync_mode_switch()
            return

        # niri palette is live even if the GTK part failed: reflect that.
        self.theme = tid
        self.sync_gtk_prefer_dark()
        self.reload_css()

        if hasattr(self, "theme_value"):
            self.theme_value.set_label(self.theme_name(tid))
        for key, button in self.theme_cards.items():
            if key == tid:
                button.add_css_class("active")
            else:
                button.remove_css_class("active")
        self.sync_mode_switch()

        if rc2 != 0:
            self.toast(last_line(err2 or out2) or self.t["theme_fail"], ok=False)
            return

        message = self.t["theme_ok"].format(name=self.theme_name(tid))
        qt_apps = parse_kv(out2).get("QT_RESTART", "")
        if qt_apps:
            message += " · " + self.t["qt_restart"].format(apps=qt_apps)
        self.toast(message)

    # ------------------------------------------------------- wallpaper ---
    def wallpaper_state(self):
        rc, out, _ = sh([WALLPAPER, "get"], timeout=20)
        if "|" in out:
            path, mode = out.split("|", 1)
            return path.strip(), mode.strip()
        return "", "fill"

    def page_wallpaper(self):
        win, body = scrolled_page()
        body.append(heading(self.t["wallpaper"], self.t["wallpaper_sub"]))
        path, mode = self.wallpaper_state()
        self.wp_path = path

        pic = Gtk.Picture()
        pic.set_can_shrink(True)
        pic.set_content_fit(Gtk.ContentFit.CONTAIN)
        pic.add_css_class("wp-preview")
        pic.set_size_request(-1, 340)
        if path and os.path.isfile(path):
            pic.set_file(Gio.File.new_for_path(path))
        self.wp_pic = pic
        body.append(pic)

        pick = Gtk.Button(label=self.t["choose_image"])
        pick.connect("clicked", self.choose_image)

        self.wp_mode_ids = WALL_MODES
        self.wp_mode = Gtk.DropDown.new_from_strings(
            [self.t["mode_" + m] for m in WALL_MODES])
        self.wp_mode.set_selected(WALL_MODES.index(mode) if mode in WALL_MODES else 0)

        apply_btn = Gtk.Button(label=self.t["apply"])
        apply_btn.add_css_class("suggested")
        apply_btn.connect("clicked", self.apply_wallpaper)

        self.wp_label = label(path or "—", "mono", wrap=True)
        body.append(card(
            hrow(pick, self.wp_mode, apply_btn, spacing=10),
            self.wp_label, spacing=10))
        return win

    def choose_image(self, *args):
        dialog = Gtk.FileDialog(title=self.t["choose_image"], modal=True)
        image_filter = Gtk.FileFilter()
        image_filter.set_name(self.t["images"])
        for pattern in ("*.png", "*.jpg", "*.jpeg", "*.webp"):
            image_filter.add_pattern(pattern)
        store = Gio.ListStore.new(Gtk.FileFilter)
        store.append(image_filter)
        dialog.set_filters(store)
        dialog.set_default_filter(image_filter)
        dialog.open(self, None, self.on_image_chosen)

    def on_image_chosen(self, dialog, result, *args):
        try:
            gfile = dialog.open_finish(result)
        except GLib.Error:
            return
        path = gfile.get_path() if gfile else None
        if not path:
            return
        self.wp_path = path
        self.wp_pic.set_file(Gio.File.new_for_path(path))
        self.wp_label.set_label(path)

    def apply_wallpaper(self, *args):
        if not self.wp_path:
            self.toast(self.t["wp_fail"], ok=False)
            return
        mode = self.wp_mode_ids[self.wp_mode.get_selected()]
        rc, out, err = sh([WALLPAPER, "set", self.wp_path, mode], timeout=90)
        if rc != 0:
            self.toast(last_line(err or out) or self.t["wp_fail"], ok=False)
            return
        self.wp_label.set_label(out.replace("|", "  ·  "))
        self.toast(self.t["wp_ok"])

    # ---------------------------------------------------------- windows ---
    def page_windows(self):
        win, body = scrolled_page()
        body.append(heading(self.t["windows"], self.t["windows_sub"]))
        current = self.info.get("radius", "12")
        group = None
        rows = []
        for px in ("0", "6", "12", "18"):
            radio = Gtk.CheckButton(label="%s px" % px)
            if group is None:
                group = radio
            else:
                radio.set_group(group)
            radio.set_active(px == current)
            radio.connect("toggled", self.on_radius_toggled, px)
            rows.append(radio)
        body.append(card(*rows, spacing=8))
        body.append(label(self.t["radius_hint"], "sub"))
        return win

    def on_radius_toggled(self, button, px, *args):
        if self.loading or not button.get_active():
            return
        rc, out, err = sh([CLI, "radius", px], timeout=60)
        if rc != 0:
            self.toast(last_line(err or out) or self.t["cfg_fail"], ok=False)
            return
        self.info["radius"] = px
        self.toast(self.t["saved"])

    # ------------------------------------------------------------ panel ---
    def page_panel(self):
        win, body = scrolled_page()
        body.append(heading(self.t["panel"], self.t["panel_sub"]))
        rc, out, _ = sh([CLI, "waybar-list"], timeout=20)
        module_names = {
            "niri/language": "Layout",
            "network": "Network", "pulseaudio": "Sound", "cpu": "CPU",
            "memory": "RAM", "battery": "Battery", "clock": "Clock",
            "tray": "Tray", "custom/power": "Power",
            "custom/ai-status": "AI agents",
        }
        box = card(spacing=6)
        found = False
        for line in out.splitlines():
            if "\t" not in line:
                continue
            module, state = line.split("\t", 1)
            found = True
            checkbox = Gtk.CheckButton(label=module_names.get(module, module))
            checkbox.set_active(state.strip() == "1")
            checkbox.connect("toggled", self.on_module_toggled, module)
            box.append(checkbox)
        if not found:
            box.append(label(self.t["ai_no_percent"], "dim"))
        body.append(box)

        restart = Gtk.Button(label=self.t["panel_restart"])
        restart.connect("clicked", self.on_panel_restart)
        body.append(restart)
        return win

    def on_module_toggled(self, button, module, *args):
        if self.loading:
            return
        rc, out, err = sh([CLI, "waybar-toggle", module], timeout=60)
        if rc != 0:
            self.toast(last_line(err or out) or self.t["panel"], ok=False)

    def on_panel_restart(self, *args):
        rc, out, err = sh([CLI, "waybar-restart"], timeout=60)
        self.toast(self.t["panel_restarted"] if rc == 0 else (err or out), ok=rc == 0)

    # ------------------------------------------------------------- keys ---
    def page_keys(self):
        win, body = scrolled_page()
        body.append(heading(self.t["keys"], self.t["keys_sub"]))
        view = Gtk.TextView()
        view.set_editable(False)
        view.set_cursor_visible(False)
        view.set_monospace(True)
        view.set_left_margin(10)
        view.set_top_margin(8)
        rc, out, _ = sh([CLI, "hotkeys"], timeout=30)
        view.get_buffer().set_text(out or "—")
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_height(400)
        scroll.set_child(view)
        body.append(card(scroll, spacing=0))

        buttons = hrow(spacing=10)
        refresh = Gtk.Button(label=self.t["refresh"])
        refresh.connect("clicked", self.on_keys_refresh)
        open_btn = Gtk.Button(label=self.t["open_config"])
        open_btn.connect("clicked", self.on_open_config)
        buttons.append(refresh)
        buttons.append(open_btn)
        body.append(buttons)
        return win

    def on_keys_refresh(self, *args):
        self.rebuild("keys")

    def on_open_config(self, *args):
        self.open_path(KDL)

    # ------------------------------------------------------------- lock ---
    def idle_values(self):
        lock, sleep = 5, 15
        try:
            with open(os.path.join(SCRIPTS, "idle.sh"), encoding="utf-8") as fh:
                text = fh.read()
        except OSError:
            return lock, sleep
        values = [int(v) for v in re.findall(r"timeout\s+(\d+)", text)]
        if len(values) > 0:
            lock = max(1, values[0] // 60)
        if len(values) > 1:
            sleep = max(1, values[1] // 60)
        return lock, sleep

    def page_lock(self):
        win, body = scrolled_page()
        body.append(heading(self.t["lock"], self.t["lock_sub"]))
        lock, sleep = self.idle_values()

        self.spin_lock = Gtk.SpinButton.new_with_range(1, 240, 1)
        self.spin_lock.set_value(lock)
        self.spin_sleep = Gtk.SpinButton.new_with_range(1, 480, 1)
        self.spin_sleep.set_value(sleep)

        save = Gtk.Button(label=self.t["save"])
        save.add_css_class("suggested")
        save.connect("clicked", self.save_idle)

        body.append(card(
            value_row(label(self.t["lock_after"]), self.spin_lock),
            value_row(label(self.t["sleep_after"]), self.spin_sleep),
            spacing=10))
        body.append(save)
        return win

    def save_idle(self, *args):
        lock = int(self.spin_lock.get_value())
        sleep = int(self.spin_sleep.get_value())
        rc, out, err = sh([CLI, "idle", str(lock), str(sleep)], timeout=45)
        if rc != 0:
            self.toast(last_line(err or out) or self.t["saved"], ok=False)
            return
        self.toast(self.t["saved"])

    # ------------------------------------------------------------- apps ---
    def page_apps(self):
        win, body = scrolled_page()
        body.append(heading(self.t["apps"], self.t["apps_sub"]))
        browser = sh(["xdg-settings", "get", "default-web-browser"], timeout=10)[1]
        fileman = sh(["xdg-mime", "query", "default", "inode/directory"], timeout=10)[1]
        editor = sh(["xdg-mime", "query", "default", "text/plain"], timeout=10)[1]

        self.ent_browser = Gtk.Entry()
        self.ent_browser.set_text(browser.replace(".desktop", ""))
        self.ent_fm = Gtk.Entry()
        self.ent_fm.set_text(fileman.replace(".desktop", ""))
        self.ent_editor = Gtk.Entry()
        self.ent_editor.set_text(editor.replace(".desktop", ""))

        save = Gtk.Button(label=self.t["save"])
        save.add_css_class("suggested")
        save.connect("clicked", self.save_apps)

        body.append(card(
            value_row(label(self.t["browser"]), self.ent_browser),
            value_row(label(self.t["filemanager"]), self.ent_fm),
            value_row(label(self.t["editor"]), self.ent_editor),
            spacing=10))
        body.append(hrow(save))
        body.append(label(self.t["apps_hint"], "sub", wrap=True))
        return win

    def save_apps(self, *args):
        command = [CLI, "defaults",
                   self.ent_browser.get_text().strip() or "-",
                   self.ent_fm.get_text().strip() or "-",
                   self.ent_editor.get_text().strip() or "-"]
        rc, out, err = sh(command, timeout=30)
        if rc != 0:
            self.toast(last_line(err or out) or self.t["saved"], ok=False)
            return
        self.toast(self.t["saved"])

    # --------------------------------------------------------------- ai ---
    def page_ai(self):
        win, body = scrolled_page()
        body.append(heading(self.t["ai"], self.t["ai_sub"]))
        conf = read_conf(AI_CONF)
        enabled = conf.get("ENABLED", "1") != "0"
        agents = [a for a in conf.get("AGENTS", "").split(",") if a]

        self.ai_switch = Gtk.Switch()
        self.ai_switch.set_active(enabled)
        self.ai_switch.set_valign(Gtk.Align.CENTER)
        self.ai_switch.connect("state-set", self.on_ai_toggle)
        body.append(card(value_row(label(self.t["ai_enable"]), self.ai_switch), spacing=8))

        agent_box = card(spacing=6)
        agent_box.append(label(self.t["ai_agents"], "h2"))
        for aid in AGENT_IDS:
            checkbox = Gtk.CheckButton(label=self.agent_label(aid))
            checkbox.set_active(aid in agents)
            checkbox.connect("toggled", self.on_agent_toggled, aid)
            agent_box.append(checkbox)
        body.append(agent_box)

        budget = card(spacing=6)
        budget.append(label(self.t["ai_budget"], "h2"))
        self.ai_budget_entries = {}
        for aid in AGENT_IDS:
            entry = Gtk.Entry()
            entry.set_width_chars(10)
            entry.set_text(conf.get("LIMIT_" + aid.upper(), "0"))
            self.ai_budget_entries[aid] = entry
            budget.append(value_row(label(self.agent_label(aid)), entry))
        body.append(budget)
        body.append(label(self.t["ai_budget_hint"], "sub", wrap=True))

        self.ai_status_box = card(spacing=6)
        body.append(self.ai_status_box)
        self.fill_ai_status()

        buttons = hrow(spacing=10)
        save = Gtk.Button(label=self.t["save"])
        save.add_css_class("suggested")
        save.connect("clicked", self.save_ai)
        refresh = Gtk.Button(label=self.t["ai_refresh"])
        refresh.connect("clicked", self.refresh_ai)
        buttons.append(save)
        buttons.append(refresh)
        body.append(buttons)

        keys = card(spacing=6)
        keys.append(label(self.t["ai_keys"], "h2"))
        self.ai_key_entries = {}
        for key, text_key in KEY_FIELDS:
            entry = Gtk.Entry()
            entry.set_visibility(False)
            entry.set_placeholder_text(self.t["ai_keep"])
            entry.set_input_purpose(Gtk.InputPurpose.PASSWORD)
            self.ai_key_entries[key] = entry
            keys.append(value_row(label(self.t[text_key]), entry))
        body.append(keys)
        return win

    def agent_label(self, aid):
        names = {"opencode": "OpenCode", "freebuff": "Freebuff",
                 "claude": "Claude Code", "codex": "Codex", "kimi": "Kimi Code"}
        return names.get(aid, aid)

    def fill_ai_status(self):
        while True:
            child = self.ai_status_box.get_first_child()
            if child is None:
                break
            self.ai_status_box.remove(child)
        self.ai_status_box.append(label(self.t["ai"], "h2"))

        rc, out, _ = sh([CLI, "ai-cache"], timeout=20)
        try:
            data = json.loads(out)
        except (ValueError, TypeError):
            data = {}
        agents = data.get("agents") or []
        if not agents:
            self.ai_status_box.append(label(self.t["ai_no_percent"], "dim"))
            return
        states = {
            "active": self.t["ai_state_active"],
            "idle": self.t["ai_state_idle"],
            "absent": self.t["ai_state_absent"],
        }
        for agent in agents:
            name = label(agent.get("name") or agent.get("id") or "?")
            name.set_size_request(140, -1)
            state = states.get(agent.get("state"), agent.get("state") or "")
            percent = agent.get("percent")
            bar = Gtk.ProgressBar()
            bar.set_hexpand(True)
            bar.set_valign(Gtk.Align.CENTER)
            if isinstance(percent, int):
                bar.set_fraction(min(1.0, percent / 100.0))
                bar.set_show_text(True)
                bar.set_text("%d%%" % percent)
            else:
                bar.set_fraction(0.0)
                bar.set_show_text(True)
                bar.set_text(self.t["ai_no_percent"])
            used, limit = agent.get("used"), agent.get("limit")
            hint = state
            if isinstance(used, int) and isinstance(limit, int):
                hint = "%s · %s/%s" % (state, used, limit)
            self.ai_status_box.append(hrow(name, bar, label(hint, "dim"), spacing=12))

    def on_ai_toggle(self, switch, state, *args):
        if self.loading:
            return False
        rc, out, err = sh([CLI, "ai-toggle", "1" if state else "0"], timeout=45)
        if rc != 0:
            self.toast(last_line(err or out) or self.t["saved"], ok=False)
            return False
        self.toast(self.t["saved"])
        return False

    def on_agent_toggled(self, button, aid, *args):
        if self.loading:
            return
        rc, out, err = sh([CLI, "ai-agent", aid, "1" if button.get_active() else "0"],
                          timeout=45)
        if rc != 0:
            self.toast(last_line(err or out) or self.t["saved"], ok=False)

    def save_ai(self, *args):
        failures = []
        for aid, entry in self.ai_budget_entries.items():
            value = entry.get_text().strip() or "0"
            if not value.isdigit():
                failures.append("LIMIT_" + aid.upper())
                continue
            rc, out, err = sh([CLI, "ai-key", "LIMIT_" + aid.upper(), value], timeout=30)
            if rc != 0:
                failures.append("LIMIT_" + aid.upper())
        for key, entry in self.ai_key_entries.items():
            value = entry.get_text().strip()
            if not value:
                continue
            rc, out, err = sh([CLI, "ai-key", key, value], timeout=30)
            if rc == 0:
                entry.set_text("")
            else:
                failures.append(key)
        if failures:
            self.toast(", ".join(failures), ok=False)
            return
        self.refresh_ai()

    def refresh_ai(self, *args):
        sh([CLI, "ai-cache"], timeout=10)
        sh([os.path.join(SCRIPTS, "ai-status.sh"), "--refresh"], timeout=60)
        self.fill_ai_status()
        self.toast(self.t["ai_updated"])

    # ---------------------------------------------------------- updates ---
    def page_updates(self):
        win, body = scrolled_page()
        body.append(heading(self.t["updates"], self.t["updates_sub"]))

        niri_ver = sh(["niri", "--version"], timeout=15)[1].splitlines()
        waybar_ver = sh(["waybar", "--version"], timeout=15)[1].splitlines()
        body.append(card(
            value_row(label(self.t["version"]), label(self.version, "value")),
            value_row(label(self.t["niri_version"]),
                      label(niri_ver[0] if niri_ver else "—", "dim")),
            value_row(label(self.t["waybar_version"]),
                      label(waybar_ver[0] if waybar_ver else "—", "dim")),
            spacing=8))

        buttons = hrow(spacing=10)
        for text, script in (
            (self.t["update_now"], "update.sh"),
            (self.t["rollback"], "rollback.sh"),
            (self.t["system_update"], "system-update.sh"),
        ):
            button = Gtk.Button(label=text)
            button.connect("clicked", self.on_run_script, script)
            buttons.append(button)
        body.append(buttons)

        check = Gtk.Button(label=self.t["check_cfg"])
        check.connect("clicked", self.on_validate)
        body.append(check)
        return win

    def on_run_script(self, _button, script, *args):
        self.launch(os.path.join(SCRIPTS, script))

    def on_validate(self, *args):
        rc, out, err = sh(["niri", "validate", "-c", KDL], timeout=30)
        lines = (out or err).splitlines()
        if rc == 0:
            self.toast(self.t["cfg_ok"])
        else:
            self.toast(lines[-1] if lines else self.t["cfg_fail"], ok=False)

    # ---------------------------------------------------------- cleanup ---
    def page_cleanup(self):
        win, body = scrolled_page()
        body.append(heading(self.t["cleanup"], self.t["cleanup_sub"]))
        rc, out, _ = sh([CLI, "cleanup-list"], timeout=20)
        items = []
        for line in out.splitlines():
            if "|" in line:
                title, path = line.split("|", 1)
                items.append((title.strip(), path.strip()))

        self.cleanup_boxes = []
        box = card(spacing=6)
        if not items:
            box.append(label(self.t["cleanup_none"], "dim"))
        for title, path in items:
            checkbox = Gtk.CheckButton(label="%s  ·  %s" % (title, os.path.basename(path)))
            checkbox.set_tooltip_text(path)
            checkbox.set_active(True)
            box.append(checkbox)
            self.cleanup_boxes.append((checkbox, path))
        body.append(box)

        move = Gtk.Button(label=self.t["cleanup_btn"])
        move.add_css_class("danger")
        move.set_sensitive(bool(items))
        move.connect("clicked", self.on_cleanup)
        body.append(hrow(move))
        return win

    def on_cleanup(self, *args):
        paths = [path for checkbox, path in self.cleanup_boxes if checkbox.get_active()]
        if not paths:
            return
        dialog = Gtk.AlertDialog(modal=True)
        dialog.set_message(self.t["cleanup_confirm"])
        dialog.set_detail("\n".join(os.path.basename(p) for p in paths))
        dialog.set_buttons([self.t["cancel"], self.t["cleanup_btn"]])
        dialog.set_cancel_button(0)
        dialog.set_default_button(0)
        dialog.choose(self, None, self.on_cleanup_choice, paths)

    def on_cleanup_choice(self, dialog, result, paths, *args):
        try:
            choice = dialog.choose_finish(result)
        except GLib.Error:
            return
        if choice != 1:
            return
        rc, out, err = sh([CLI, "cleanup-move", *paths], timeout=60)
        if rc != 0:
            self.toast(last_line(err or out) or self.t["cleanup_btn"], ok=False)
            return
        moved = "0"
        for part in out.split():
            if part.startswith("moved="):
                moved = part.split("=", 1)[1]
        self.toast(self.t["cleanup_done"].format(n=moved))
        self.rebuild("cleanup")

    # --------------------------------------------------------- language ---
    def page_language(self):
        win, body = scrolled_page()
        body.append(heading(self.t["language"], self.t["language_sub"]))
        group = None
        rows = []
        for code, name in (("ru", "Русский"), ("en", "English")):
            radio = Gtk.CheckButton(label=name)
            if group is None:
                group = radio
            else:
                radio.set_group(group)
            radio.set_active(code == self.lang)
            radio.connect("toggled", self.on_language_toggled, code)
            rows.append(radio)
        body.append(card(*rows, spacing=8))

        restart = Gtk.Button(label=self.t["lang_restart"])
        restart.connect("clicked", self.on_language_restart)
        body.append(hrow(restart))
        return win

    def on_language_toggled(self, button, code, *args):
        if self.loading or not button.get_active() or code == self.lang:
            return
        rc, out, err = sh([CLI, "lang", code], timeout=30)
        if rc != 0:
            self.toast(last_line(err or out) or self.t["saved"], ok=False)
            return
        self.toast(self.t["saved"])
        GLib.timeout_add(400, self.restart_after_language)

    def restart_after_language(self, *args):
        self.restart_app("language")
        return GLib.SOURCE_REMOVE

    def on_language_restart(self, *args):
        self.restart_app("language")

    # ------------------------------------------------------------ about ---
    def page_about(self):
        win, body = scrolled_page()
        body.append(heading(self.t["about"], self.t["about_sub"]))
        body.append(card(
            value_row(label(self.t["version"]), label(self.version, "value")),
            value_row(label(self.t["theme"]), label(self.theme_name(self.theme), "value")),
            value_row(label(self.t["language"]), label(self.lang.upper(), "value")),
            value_row(label(self.t["config_path"]), label(CONF, "mono")),
            value_row(label(self.t["cache_path"]), label(CACHE_DIR, "mono")),
            spacing=8))

        repo = Gtk.Button(label=self.t["repo"])
        repo.connect("clicked", self.on_open_repo)
        body.append(hrow(repo))
        return win

    def on_open_repo(self, *args):
        self.open_path(REPO_URL)


class SettingsApp(Gtk.Application):
    def __init__(self, start_page=None):
        super().__init__()
        self.start_page = start_page

    def do_activate(self):
        set_gtk_dark_preference(theme_mode(current_theme_id()) == "dark")
        win = SettingsWindow(self, self.start_page)
        win.present()


def main():
    page = None
    args = sys.argv[1:]
    for index, arg in enumerate(args):
        if arg == "--page" and index + 1 < len(args):
            page = args[index + 1]
        elif arg.startswith("--page="):
            page = arg.split("=", 1)[1]
    return SettingsApp(page).run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
