#!/bin/bash
# Получаем текущую раскладку через niri msg
# Niri выводит что-то вроде: "Keyboard layouts: us, ru (active: us)"
# Мы вытаскиваем активную раскладку и переводим в верхний регистр
layout=$(niri msg keyboard-layouts | grep -oP 'active: \K[a-zA-Z]+' | tr '[:lower:]' '[:upper:]')

if [ -z "$layout" ]; then
    echo "??"
else
    echo "$layout"
fi
