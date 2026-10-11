#!/bin/bash

# Shows OSD toast when power profile changes via Fn+F5
# Also switches supergfxctl GPU mode based on profile

current_profile=$(asusctl profile get 2>/dev/null | grep "Active profile" | awk '{print $3}')

case "$current_profile" in
    "Quiet")
        icon="battery-profile-powersave"
        message="Profile: Quiet (Power Saver)"
        supergfxctl -m Integrated 2>/dev/null || true
        ;;
    "Balanced")
        icon="battery-060"
        message="Profile: Balanced"
        supergfxctl -m Integrated 2>/dev/null || true
        ;;
    "Performance")
        icon="battery-profile-performance"
        message="Profile: Performance"
        supergfxctl -m Hybrid 2>/dev/null || true
        ;;
    *)
        icon="preferences-system-power-management"
        message="Profile: $current_profile"
        ;;
esac

# Show OSD toast notification
if command -v qdbus &> /dev/null; then
    qdbus org.kde.plasmashell /org/kde/osdService org.kde.osdService.showText "$icon" "$message" 2>/dev/null
elif command -v dbus-send &> /dev/null; then
    dbus-send --type=method_call --dest=org.kde.plasmashell /org/kde/osdService org.kde.osdService.showText string:"$icon" string:"$message" 2>/dev/null
elif command -v notify-send &> /dev/null; then
    notify-send -i "$icon" -t 2000 "ASUS Profile" "$message"
else
    echo "$message"
fi

exit 0
