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
	network-manager-gnome
	thunar thunar-archive-plugin gvfs tumbler
	fonts-inter fonts-noto-color-emoji fonts-dejavu-core
	papirus-icon-theme adwaita-icon-theme
	xdg-utils curl xz-utils fontconfig
)

c_blue=$'\e[1;34m'; c_yellow=$'\e[1;33m'; c_red=$'\e[1;31m'; c_off=$'\e[0m'
step() { printf '\n%s==>%s %s\n' "$c_blue" "$c_off" "$*"; }
warn() { printf '%s!!%s  %s\n' "$c_yellow" "$c_off" "$*"; }
die()  { printf '%sxx%s  %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }
usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# Copy src -> dst, backing up dst first if it exists and differs.
install_file() {
	local src="$1" dst="$2" rel
	rel="${dst#"$HOME"/}"
	if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
		mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
		cp -a "$dst" "$BACKUP_DIR/$rel"
	fi
	mkdir -p "$(dirname "$dst")"
	cp "$src" "$dst"
}

# Keyboard layout from PikaOS's Hyprland config, then the system setting
detect_layout() {
	local l=""
	if [ -d "$CONFIG_HOME/hypr" ]; then
		l="$(grep -rhoE 'kb_layout[[:space:]]*=[[:space:]]*"[^"]*"' "$CONFIG_HOME/hypr" 2>/dev/null |
			head -n1 | sed 's/.*"\(.*\)"/\1/')"
	fi
	if [ -z "$l" ] || [ "$l" = "@KB_LAYOUT@" ]; then
		l="$(localectl status 2>/dev/null | sed -n 's/.*X11 Layout:[[:space:]]*//p' | head -n1)"
	fi
	echo "${l:-us}"
}

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

HYPR_VER="$(hyprctl version 2>/dev/null | sed -n 's/^Tag: v\{0,1\}\([0-9.]*\).*/\1/p' | head -n1)"
[ -n "$HYPR_VER" ] || HYPR_VER="$(Hyprland --version 2>/dev/null | sed -n 's/^Hyprland \([0-9.]*\).*/\1/p' | head -n1)"
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
	sudo -v
	step "Updating package lists"
	sudo apt-get update

	step "Checking packages"
	avail=()
	for p in "${PKGS[@]}"; do
		if apt-cache show "$p" >/dev/null 2>&1; then
			avail+=("$p")
		else
			warn "package $p is not available, skipping it"
		fi
	done

	step "Installing packages"
	sudo apt-get install -y "${avail[@]}"

	# A polkit agent for password prompts, if PikaOS doesn't already have one
	if ! ls /usr/lib/hyprpolkitagent/hyprpolkitagent /usr/libexec/hyprpolkitagent \
	        /usr/libexec/polkit-mate-authentication-agent-1 \
	        /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 \
	        /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 \
	        /usr/bin/lxpolkit >/dev/null 2>&1; then
		for agent in hyprpolkitagent mate-polkit lxpolkit; do
			if apt-cache show "$agent" >/dev/null 2>&1; then
				sudo apt-get install -y "$agent" && break
			fi
		done
	fi
fi

# Icons in the panel come from the Nerd Fonts symbols font
if ! fc-list 2>/dev/null | grep -qi 'Symbols Nerd Font'; then
	step "Installing the Nerd Fonts symbols font"
	tmp="$(mktemp -d)"
	if curl -fsSL -o "$tmp/sym.tar.xz" \
		https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz; then
		mkdir -p "$HOME/.local/share/fonts/NerdFontsSymbolsOnly"
		tar -xJf "$tmp/sym.tar.xz" -C "$HOME/.local/share/fonts/NerdFontsSymbolsOnly"
		fc-cache -f >/dev/null 2>&1 || true
		echo "    ~/.local/share/fonts/NerdFontsSymbolsOnly"
	else
		warn "couldn't download the symbols font; some panel icons may show as boxes"
	fi
	rm -rf "$tmp"
fi

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
		sudo apt-get install -y cmake meson ninja-build cpio pkg-config git g++ gcc make || true
		if ! sudo apt-get build-dep -y hyprland; then
			warn "couldn't install Hyprland's build dependencies automatically (apt-get build-dep hyprland)"
		fi
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
step "Installing helper scripts to /usr/local/bin"
for f in setupde-powermenu setupde-screenshot setupde-clipboard; do
	sudo install -m 755 "$REPO_DIR/bin/$f" /usr/local/bin/
	echo "    $f"
done

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
	qt_theme="$(sed -n 's/.*"QT_QPA_PLATFORMTHEME"[[:space:]]*,[[:space:]]*"\([^"]*\)".*/\1/p' "$HYPR_BACKUP"/*.lua 2>/dev/null | head -n1)"
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
step "Installing app configs (shared with the labwc setup)"
for rel in waybar/config.jsonc waybar/style.css fuzzel/fuzzel.ini foot/foot.ini \
           mako/config swaylock/config gtk-3.0/settings.ini; do
	install_file "$REPO_DIR/config/$rel" "$CONFIG_HOME/$rel"
	echo "    $rel"
done
install_file "$REPO_DIR/config/gtk-3.0/settings.ini" "$CONFIG_HOME/gtk-4.0/settings.ini"

if command -v gsettings >/dev/null; then
	gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
	gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true
	gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark 2>/dev/null || true
	gsettings set org.gnome.desktop.interface cursor-theme Adwaita 2>/dev/null || true
	gsettings set org.gnome.desktop.interface font-name 'Inter 10' 2>/dev/null || true
fi
mkdir -p "$HOME/Pictures/Screenshots"
[ -d "$BACKUP_DIR" ] && warn "replaced app configs were backed up to $BACKUP_DIR"

# ---------------------------------------------------------------- otter-shell
# PikaOS's own shell (panel, launcher, notifications) would run next to waybar
# and mako if something other than the old hypr config starts it.
OTTER_UNITS="$(systemctl --user list-unit-files 2>/dev/null | awk '{print $1}' | grep -i otter || true)"
if [ -n "$OTTER_UNITS" ]; then
	step "Turning off PikaOS's otter-shell (waybar + mako replace it)"
	for u in $OTTER_UNITS; do
		systemctl --user disable --now "$u" 2>/dev/null || true
		echo "    disabled $u   (undo: systemctl --user enable --now $u)"
	done
fi
for f in /etc/xdg/autostart/*otter*.desktop; do
	[ -f "$f" ] || continue
	mkdir -p "$CONFIG_HOME/autostart"
	printf '[Desktop Entry]\nHidden=true\n' > "$CONFIG_HOME/autostart/$(basename "$f")"
	echo "    hid autostart entry $(basename "$f")   (undo: rm ~/.config/autostart/$(basename "$f"))"
done

cat <<EOF

${c_blue}Done!${c_off}  Log out and back in (Super+Shift+E) to start everything.

  Super+Space  launcher       Super+Enter  terminal      Super+E   files
  Super+T      tile/float     Super+Shift+T  whole workspace  Super+Q  close
  Super+C      centre
  Super+Esc    power menu     Alt+Tab      switch        Print     screenshot

  To go back to PikaOS's Hyprland setup:
    rm -rf ~/.config/hypr && mv "$HYPR_BACKUP" ~/.config/hypr

EOF
