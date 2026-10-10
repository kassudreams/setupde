#!/bin/sh
# Run once when Hyprland starts (from autostart.lua).
# Long-running programs must end with '&'.

# Wallpaper: put an image at ~/.config/hypr/wallpaper (any jpg/png) to use it
if [ -f "$HOME/.config/hypr/wallpaper" ]; then
	swaybg -m fill -i "$HOME/.config/hypr/wallpaper" >/dev/null 2>&1 &
else
	swaybg -c '#1e1e2e' >/dev/null 2>&1 &
fi

# Title bars (hyprbars plugin), then reload the config so bars.lua applies
if command -v hyprpm >/dev/null; then
	{ hyprpm reload -n && hyprctl reload; } >/dev/null 2>&1 &
fi

# Panel (the dock in its middle is generated first) and notifications
command -v setupde-dock >/dev/null && setupde-dock build
waybar >/dev/null 2>&1 &
# keeps the dock's pinned icons in sync with open windows
command -v setupde-dock >/dev/null && setupde-dock watch >/dev/null 2>&1 &
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

# No nm-applet / blueman tray icons: the network icon in the panel has the
# menu (setupde-network), so they'd only show the same thing twice.

# Clipboard history (Super+V)
command -v cliphist >/dev/null && wl-paste --watch cliphist store >/dev/null 2>&1 &

# Night light + brightness with your saved settings (moon icon in the panel)
command -v setupde-nightlight >/dev/null && setupde-nightlight restore

# Idle: lock after 5 min, screen off after 10 min, lock before suspend.
# "lock" also answers `loginctl lock-session` from anything else (PikaOS's
# otter tools use it), so the lock screen is always swaylock - type your
# password and press Enter.
pkill -x otter-idle 2>/dev/null
swayidle -w \
	lock 'pidof swaylock || swaylock -f' \
	timeout 300 'swaylock -f' \
	timeout 600 "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'" \
	resume "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'" \
	before-sleep 'swaylock -f' >/dev/null 2>&1 &
