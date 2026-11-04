#!/usr/bin/env bash
# ============================================================
#  FlowNiri — settings launcher
#
#  Opens the GTK4 control centre (sidebar + pages). When PyGObject or GTK4 is
#  missing it falls back to the zenity menu, so the binding always works.
#
#  Usage: flowniri-settings.sh [--page themes|wallpaper|panel|ai|...]
# ============================================================
set -o pipefail

FLOW_DIR="$HOME/.config/FlowNiri"

if python3 -c 'import gi; gi.require_version("Gtk", "4.0"); from gi.repository import Gtk' >/dev/null 2>&1; then
    exec python3 "$FLOW_DIR/ui/settings.py" "$@"
fi

exec "$HOME/.config/scripts/flowniri-menu.sh" "$@"
