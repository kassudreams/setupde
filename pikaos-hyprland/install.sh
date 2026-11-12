#!/bin/bash
# setupde for PikaOS Hyprland - the Catppuccin Mocha look with floating windows.
#
# Run as your normal user (NOT root), from this folder:
#     ./install.sh
#
# Your current Hyprland config is moved to ~/.config/hypr.pikaos-backup-<date>
# and any other config it replaces goes to ~/.config/setupde-backup-<date>.
#
# Options:
#     -y, --yes        don't ask for confirmation
#     --layout=XX      keyboard layout, e.g. fi, us  (default: taken from PikaOS's config)
#     --no-packages    only install the configs and scripts
#     -h, --help       show this help

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$HERE")"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$CONFIG_HOME/setupde-backup-$STAMP"
HYPR_BACKUP="$CONFIG_HOME/hypr.pikaos-backup-$STAMP"

ASSUME_YES=0
LAYOUT=""
WANT_PACKAGES=1

PKGS=(
	waybar fuzzel foot mako-notifier
	swaybg swaylock swayidle wlsunset
	grim slurp swappy wl-clipboard cliphist
	brightnessctl playerctl pavucontrol libnotify-bin
	network-manager-gnome usbmuxd
	thunar thunar-archive-plugin gvfs tumbler
	fonts-inter fonts-noto-color-emoji fonts-dejavu-core
	papirus-icon-theme adwaita-icon-theme
	xdg-utils curl xz-utils fontconfig
	hyprsunset python3-gi gir1.2-gtk-3.0 libgtk-3-bin btop nvtop socat
	gnome-disk-utility gparted x11-xserver-utils exfatprogs ntfs-3g dosfstools
)

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# step/warn/die, install_file, detect_layout and the steps shared with the
# labwc installer
# shellcheck source=../pikaos-common.sh
. "$REPO_DIR/pikaos-common.sh"

for arg in "$@"; do
	case "$arg" in
		-y|--yes) ASSUME_YES=1 ;;
		--layout=*) LAYOUT="${arg#*=}" ;;
		--no-packages) WANT_PACKAGES=0 ;;
		-h|--help) usage ;;
		*) die "unknown option: $arg (see --help)" ;;
	esac
done

# ---------------------------------------------------------------- checks
[ "$(id -u)" -ne 0 ] || die "run this as your normal user, not root (it uses sudo when needed)"
command -v apt-get >/dev/null || die "this script is for PikaOS / Debian-based systems (apt not found)"
command -v hyprctl >/dev/null || die "Hyprland is not installed"

HYPR_VER="$(hyprctl version 2>/dev/null | sed -n 's/^Tag: v\{0,1\}\([0-9.]*\).*/\1/p' | head -n1 || true)"
[ -n "$HYPR_VER" ] || HYPR_VER="$(Hyprland --version 2>/dev/null | sed -n 's/^Hyprland \([0-9.]*\).*/\1/p' | head -n1 || true)"
HYPR_MINOR="$(echo "$HYPR_VER" | cut -d. -f2)"
if [ -z "$HYPR_MINOR" ] || [ "$HYPR_MINOR" -lt 55 ]; then
	die "this config needs Hyprland 0.55 or newer (Lua config); found '${HYPR_VER:-unknown}'"
fi

[ -n "$LAYOUT" ] || LAYOUT="$(detect_layout)"

cat <<EOF

  setupde for PikaOS Hyprland
  ---------------------------
  Hyprland:        $HYPR_VER
  keyboard layout: $LAYOUT
  packages:        $( [ "$WANT_PACKAGES" -eq 1 ] && echo "yes (apt)" || echo no )
  your hypr config is moved to: $HYPR_BACKUP

EOF
if [ "$ASSUME_YES" -eq 0 ]; then
	read -r -p "Continue? [Y/n] " ans
	case "$ans" in [nN]*) exit 0 ;; esac
fi

# ---------------------------------------------------------------- packages
if [ "$WANT_PACKAGES" -eq 1 ]; then
	install_packages "${PKGS[@]}"
	install_polkit_agent
fi

install_symbols_font

# ---------------------------------------------------------------- title bars
# hyprbars draws title bars (drag to move, double-click for big/small).
# 1) a packaged plugin from PikaOS's repo, if there is one
# 2) otherwise build it with hyprpm (needs Hyprland's build dependencies)
PLUGIN_PATH=""
if [ "$WANT_PACKAGES" -eq 1 ]; then
	step "Setting up title bars (hyprbars plugin)"
	for pkg in hyprland-plugin-hyprbars hyprland-plugins hyprbars; do
		if apt-cache show "$pkg" >/dev/null 2>&1 && sudo apt-get install -y "$pkg"; then
			PLUGIN_PATH="$(dpkg -L "$pkg" 2>/dev/null | grep -m1 'hyprbars.*\.so$' || true)"
			[ -n "$PLUGIN_PATH" ] && break
		fi
	done

	if [ -z "$PLUGIN_PATH" ]; then
		echo "    no packaged plugin, building it with hyprpm (takes a few minutes)"
		# Everything Hyprland's build checks for (hyprpm configures the Hyprland
		# source to get its headers); the list lives in setupde-rebuild-plugins
		bash "$REPO_DIR/bin/setupde-rebuild-plugins" --deps || true
		# hyprbars includes <lua.h>; Debian keeps it in /usr/include/lua5.5
		CXXFLAGS="-O2 $(pkg-config --cflags lua5.5 2>/dev/null || echo -I/usr/include/lua5.5)"
		export CXXFLAGS
		if hyprpm update && { hyprpm list 2>/dev/null | grep -q hyprland-plugins ||
				printf 'y\n' | hyprpm add https://github.com/hyprwm/hyprland-plugins; } &&
				hyprpm enable hyprbars && hyprpm reload; then
			echo "    hyprbars built and enabled"
		else
			warn "building hyprbars failed, so windows have no title bars for now."
			warn "You can still move windows with Super+drag and use Super+M for big/small."
			warn "Send me the output of:  hyprpm update -v"
		fi
	fi
fi

# ---------------------------------------------------------------- scripts
install_scripts setupde-powermenu setupde-screenshot setupde-clipboard setupde-rebuild-plugins \
	setupde-dock setupde-sysinfo setupde-nightlight setupde-network setupde-fireface setupde-hdr \
	setupde-gamemode setupde-game setupde-plugin-check setupde-snapshot setupde-vpn \
	setupde-audio setupde-snap setupde-keys

# ---------------------------------------------------------------- hyprland config
step "Installing the Hyprland config"
if [ -d "$CONFIG_HOME/hypr" ]; then
	mv "$CONFIG_HOME/hypr" "$HYPR_BACKUP"
	echo "    old config moved to $HYPR_BACKUP"
fi
mkdir -p "$CONFIG_HOME/hypr"
cp "$HERE"/hypr/* "$CONFIG_HOME/hypr/"
chmod +x "$CONFIG_HOME/hypr/autostart.sh"
if [ -n "$PLUGIN_PATH" ]; then
	printf '-- written by install.sh: packaged hyprbars plugin\nhl.plugin.load("%s")\n' "$PLUGIN_PATH" \
		> "$CONFIG_HOME/hypr/plugins.lua"
fi
sed -i "s/@KB_LAYOUT@/$LAYOUT/" "$CONFIG_HOME/hypr/input.lua"
# Keep PikaOS's Qt theming (qt6ct/kdeglobals dark theme) instead of ours
if [ -d "$HYPR_BACKUP" ]; then
	qt_theme="$(sed -n 's/.*"QT_QPA_PLATFORMTHEME"[[:space:]]*,[[:space:]]*"\([^"]*\)".*/\1/p' "$HYPR_BACKUP"/*.lua 2>/dev/null | head -n1 || true)"
	if [ -n "$qt_theme" ]; then
		sed -i "s/hl.env(\"QT_QPA_PLATFORMTHEME\", \"[^\"]*\")/hl.env(\"QT_QPA_PLATFORMTHEME\", \"$qt_theme\")/" "$CONFIG_HOME/hypr/env.lua"
		echo "    Qt theme: $qt_theme (kept from PikaOS)"
	fi
fi
# Keep PikaOS's wallpaper if it had one in the config folder
for w in "$HYPR_BACKUP"/wallpaper.*; do
	[ -f "$w" ] && cp "$w" "$CONFIG_HOME/hypr/wallpaper" && break
done 2>/dev/null || true
# Otherwise use the setupde wallpaper
if [ ! -e "$CONFIG_HOME/hypr/wallpaper" ]; then
	cp "$REPO_DIR/wallpapers/catppuccin-floaty.jpg" "$CONFIG_HOME/hypr/wallpaper"
fi
echo "    ~/.config/hypr (keyboard layout: $LAYOUT)"

# ---------------------------------------------------------------- other configs
install_app_configs

# ---------------------------------------------------------------- PikaOS shell + locker
pikaos_shell_off

cat <<EOF

${c_blue}Done!${c_off}  Log out and back in (Super+Shift+E) to start everything.

  Super+Space  launcher       Super+Enter  terminal      Super+E   files
  Super+arrows snap           Super+T      tile all (again: undo)
  Super+C      centre         Super+Q      close         Super+F1  all shortcuts
  Super+Esc    power menu     Alt+Tab      switch        Print     screenshot

  To go back to PikaOS's Hyprland setup:
    rm -rf ~/.config/hypr && mv "$HYPR_BACKUP" ~/.config/hypr

EOF
