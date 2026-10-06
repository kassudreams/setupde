#!/bin/sh
# Run once when Hyprland starts (from autostart.lua).
# Long-running programs must end with '&'.

# Wallpaper: put an image at ~/.config/hypr/wallpaper (any jpg/png) to use it
if [ -f "$HOME/.config/hypr/wallpaper" ]; then
	swaybg -m fill -i "$HOME/.config/hypr/wallpaper" >/dev/null 2>&1 &
else
	swaybg -c '#1e1e2e' >/dev/null 2>&1 &
fi

# Panel and notifications
waybar >/dev/null 2>&1 &
mako >/dev/null 2>&1 &

# Password prompts for apps that need admin rights (first agent found)
if ! pgrep -f 'polkit.*agent|hyprpolkitagent|lxpolkit' >/dev/null; then
	for agent in /usr/lib/hyprpolkitagent/hyprpolkitagent \
	             /usr/libexec/hyprpolkitagent \
	             /usr/libexec/polkit-mate-authentication-agent-1 \
	             /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 \
	             /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 \
	             /usr/libexec/polkit-gnome-authentication-agent-1 \
	             /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 \
	             /usr/bin/lxpolkit; do
		[ -x "$agent" ] && { "$agent" >/dev/null 2>&1 & break; }
	done
fi

# Tray applets
command -v nm-applet >/dev/null && nm-applet --indicator >/dev/null 2>&1 &

# Clipboard history (Super+V)
command -v cliphist >/dev/null && wl-paste --watch cliphist store >/dev/null 2>&1 &

# Night light (warmer colours from 20:00 to 07:00). Remove if you don't want it.
command -v wlsunset >/dev/null && wlsunset -t 4000 -T 6500 -S 07:00 -s 20:00 >/dev/null 2>&1 &

# Idle: lock after 5 min, screen off after 10 min, lock before suspend
swayidle -w \
	timeout 300 'swaylock -f' \
	timeout 600 "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'" \
	resume "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'" \
	before-sleep 'swaylock -f' >/dev/null 2>&1 &
