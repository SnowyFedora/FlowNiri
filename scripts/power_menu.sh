#!/bin/bash

# Меню питания в правом верхнем углу
options="Shutdown\nReboot\nLogout"

# Запускаем rofi с кастомной позицией
# location: northeast (правый верх), anchor: northeast (точка привязки)
chosen=$(echo -e "$options" | rofi -dmenu -i -p "Power" -theme-str 'window { location: northeast; anchor: northeast; x-offset: -10px; y-offset: 10px; width: 180px; } listview { lines: 3; }')

case "$chosen" in
    "Shutdown") sudo shutdown now ;;
    "Reboot") sudo reboot ;;
    "Logout") niri msg action quit ;;
esac
