#!/bin/bash
# Git clean filter: replaces wallpaper path with placeholder on commit
sed 's|^wallpaper = .*|wallpaper = ~/.config/wallpaper/default.jpg|'
