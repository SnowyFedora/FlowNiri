#!/bin/bash
swayidle -w \
  timeout 300 'gtklock' \
  timeout 900 'systemctl suspend' \
  before-sleep 'gtklock'
