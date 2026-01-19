# Wallpaper

Default: Catppuccin Mocha gradient (included as `wallpaper.png`)

## Changing Wallpaper

```bash
# Replace with your own image
cp ~/Downloads/your-wallpaper.png ~/.config/wallpaper/wallpaper.png

# Apply immediately with animation
swww img ~/.config/wallpaper/wallpaper.png --transition-type grow --transition-pos center
```

## Catppuccin Wallpapers

- https://github.com/catppuccin/wallpapers
- https://github.com/zhichaoh/catppuccin-wallpapers

## Transition Effects

```bash
# Grow from center
swww img wallpaper.png --transition-type grow --transition-pos center

# Fade
swww img wallpaper.png --transition-type fade

# Wipe from left
swww img wallpaper.png --transition-type wipe --transition-angle 0

# Wave effect
swww img wallpaper.png --transition-type wave
```
