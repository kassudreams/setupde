#!/bin/bash
# setupde for PikaOS labwc - the same Catppuccin desktop, panel and helpers as
# the Hyprland setup, on labwc: a simple, stable Wayland desktop with HDR
# (game mode, Super+G) and VRR. It goes next to Hyprland: choose
# "labwc (setupde)" on the login screen. Hyprland and its config stay as
# they are, so you can go back to it there at any time.
#
# Run as your normal user (NOT root), from this folder:
#     ./install.sh
#
# A labwc config you already have is moved to ~/.config/labwc.backup-<date>
# and any other config it replaces goes to ~/.config/setupde-backup-<date>.
#
# Options:
#     -y, --yes        don't ask for confirmation
#     --layout=XX      keyboard layout, e.g. fi, us  (default: the one you use now)
#     --no-packages    only install the configs and scripts
#     -h, --help       show this help

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$HERE")"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$CONFIG_HOME/setupde-backup-$STAMP"
LABWC_BACKUP="$CONFIG_HOME/labwc.backup-$STAMP"
SESSION_FILE=/usr/share/wayland-sessions/setupde-labwc.desktop

ASSUME_YES=0
LAYOUT=""
WANT_PACKAGES=1

PKGS=(
	labwc xwayland wlr-randr kanshi wlopm wlrctl gammastep gamescope
	xdg-desktop-portal-wlr xdg-desktop-portal-gtk wdisplays nwg-look
	waybar fuzzel foot mako-notifier
	swaybg swaylock swayidle
	grim slurp swappy wl-clipboard cliphist
	brightnessctl playerctl pavucontrol libnotify-bin
	network-manager-gnome usbmuxd
	thunar thunar-archive-plugin gvfs tumbler
	fonts-inter fonts-noto-color-emoji fonts-dejavu-core
	papirus-icon-theme adwaita-icon-theme
	xdg-utils curl xz-utils fontconfig
	python3-gi gir1.2-gtk-3.0 libgtk-3-bin btop nvtop socat
	gnome-disk-utility gparted x11-xserver-utils exfatprogs ntfs-3g dosfstools
)

# the Hyprland-only helpers (setupde-snap, setupde-plugin-check,
# setupde-rebuild-plugins) aren't needed here
SCRIPTS=(
	start-labwc setupde-powermenu setupde-screenshot setupde-clipboard
	setupde-dock setupde-sysinfo setupde-nightlight setupde-network setupde-fireface
	setupde-hdr setupde-gamemode setupde-game setupde-snapshot setupde-vpn setupde-audio setupde-keys
)

usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# step/warn/die, install_file, detect_layout and the steps shared with the
# Hyprland installer
# shellcheck source=../pikaos-common.sh
. "$REPO_DIR/pikaos-common.sh"

# "0.20.3" from "labwc 0.20.3 (+xwayland ...) wlroots-0.20.2"
labwc_version() { labwc --version 2>/dev/null | sed -n 's/^labwc \([0-9][0-9.]*\).*/\1/p' | head -n1 || true; }
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

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
if [ "$WANT_PACKAGES" -eq 0 ] && ! command -v labwc >/dev/null; then
	die "labwc is not installed (run without --no-packages to install it)"
fi

[ -n "$LAYOUT" ] || LAYOUT="$(detect_layout)"
LABWC_VER="$(labwc_version)"
moved=""
[ -d "$CONFIG_HOME/labwc" ] && moved="
  your labwc config is moved to: $LABWC_BACKUP"

cat <<EOF

  setupde for PikaOS labwc
  ------------------------
  labwc:           ${LABWC_VER:-not installed yet (it will be)}
  keyboard layout: $LAYOUT
  packages:        $( [ "$WANT_PACKAGES" -eq 1 ] && echo "yes (apt)" || echo no )
  login screen:    a new "labwc (setupde)" choice; Hyprland stays as it is$moved

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

command -v labwc >/dev/null || die "labwc didn't install (see the apt messages above)"
LABWC_VER="$(labwc_version)"
# HDR, the snapping keys and the panel's workspace buttons need labwc 0.20
if [ -n "$LABWC_VER" ] && ! version_ge "$LABWC_VER" 0.20; then
	warn "labwc $LABWC_VER is older than 0.20: HDR and some window keys won't work"
	warn "(everything else does). PikaOS updates bring the newer labwc."
fi

# ---------------------------------------------------------------- scripts
install_scripts "${SCRIPTS[@]}"

# The login screen lists the sessions in /usr/share/wayland-sessions.
# (labwc's own "labwc" entry starts it without start-labwc: no HDR.)
step "Adding \"labwc (setupde)\" to the login screen"
printf '%s\n' \
	'[Desktop Entry]' \
	'Name=labwc (setupde)' \
	'Comment=labwc with the setupde panel, snapping, HDR and VRR' \
	'Exec=/usr/local/bin/start-labwc' \
	'Type=Application' \
	'DesktopNames=labwc;wlroots' |
	sudo tee "$SESSION_FILE" >/dev/null
echo "    $SESSION_FILE"

# ---------------------------------------------------------------- labwc config
step "Installing the labwc config"
if [ -d "$CONFIG_HOME/labwc" ]; then
	mv "$CONFIG_HOME/labwc" "$LABWC_BACKUP"
	echo "    old config moved to $LABWC_BACKUP"
fi
mkdir -p "$CONFIG_HOME/labwc"
cp "$HERE"/labwc/* "$CONFIG_HOME/labwc/"
# the theme (Catppuccin title bars) and the desktop's right-click menu are
# the same as on Void
cp "$REPO_DIR/config/labwc/themerc-override" "$REPO_DIR/config/labwc/menu.xml" "$CONFIG_HOME/labwc/"
chmod +x "$CONFIG_HOME/labwc/autostart" "$CONFIG_HOME/labwc/shutdown"
sed -i "s/@KB_LAYOUT@/$LAYOUT/" "$CONFIG_HOME/labwc/environment"

# Qt apps: the same theme setting as the Hyprland setup (PikaOS's own, kept
# by that installer), else GTK's
qt_theme="$(sed -n 's/.*"QT_QPA_PLATFORMTHEME"[[:space:]]*,[[:space:]]*"\([^"]*\)".*/\1/p' \
	"$CONFIG_HOME/hypr/env.lua" 2>/dev/null | head -n1 || true)"
[ -n "$qt_theme" ] || qt_theme="$(sed -n 's/^QT_QPA_PLATFORMTHEME=//p' "$LABWC_BACKUP/environment" 2>/dev/null | head -n1 || true)"
case "$qt_theme" in ""|@*) qt_theme=gtk3 ;; esac
sed -i "s/@QT_THEME@/$qt_theme/" "$CONFIG_HOME/labwc/environment"
echo "    Qt theme: $qt_theme"

# Wallpaper: the one labwc had, else the Hyprland one, else setupde's
for w in "$LABWC_BACKUP/wallpaper" "$CONFIG_HOME/hypr/wallpaper" "$REPO_DIR/wallpapers/catppuccin-floaty.jpg"; do
	if [ -f "$w" ]; then
		cp "$w" "$CONFIG_HOME/labwc/wallpaper"
		break
	fi
done
echo "    ~/.config/labwc (keyboard layout: $LAYOUT)"

# Monitor: the resolution, refresh rate and scale the Hyprland setup uses
# (hypr/monitors.lua), applied by kanshi
mon="$CONFIG_HOME/hypr/monitors.lua"
mode="$(sed -n 's/^[[:space:]]*mode[[:space:]]*=[[:space:]]*"\([0-9]*x[0-9]*\(@[0-9.]*\)\{0,1\}\)".*/\1/p' "$mon" 2>/dev/null | head -n1 || true)"
scale="$(sed -n 's/^[[:space:]]*scale[[:space:]]*=[[:space:]]*"\{0,1\}\([0-9.]*\)"\{0,1\}.*/\1/p' "$mon" 2>/dev/null | head -n1 || true)"
tmp_kanshi="$(mktemp)"
cp "$HERE/kanshi/config" "$tmp_kanshi"
if [ -n "$mode" ] || [ -n "$scale" ]; then
	out="output *"
	case "$mode" in *@*) out="$out mode ${mode}Hz" ;; ?*) out="$out mode $mode" ;; esac
	[ -n "$scale" ] && out="$out scale $scale"
	sed -i "s|^\([[:space:]]*\)output \*.*|\1$out|" "$tmp_kanshi"
fi
install_file "$tmp_kanshi" "$CONFIG_HOME/kanshi/config"
rm -f "$tmp_kanshi"
echo "    kanshi/config ($(sed -n 's/^[[:space:]]*output \* //p' "$CONFIG_HOME/kanshi/config"))"

# Screenshots and screen sharing through the wlroots portal, the rest GTK's
install_file "$REPO_DIR/config/xdg-desktop-portal/labwc-portals.conf" \
	"$CONFIG_HOME/xdg-desktop-portal/labwc-portals.conf"
echo "    xdg-desktop-portal/labwc-portals.conf"

# ---------------------------------------------------------------- other configs
install_app_configs

# ---------------------------------------------------------------- PikaOS shell + locker
pikaos_shell_off

cat <<EOF

${c_blue}Done!${c_off}  Log out, then choose "labwc (setupde)" on the login screen.
  (Back to Hyprland: log out and choose Hyprland there.)

  Super+Space  launcher       Super+Enter  terminal      Super+E   files
  Super+arrows snap           drag to an edge: snap      Super+M   big
  Super+C      centre         Super+Q      close         Super+F1  all shortcuts
  Super+G      game mode (HDR on)         Super+Esc    power menu

  If labwc doesn't start, its log is ~/.local/state/labwc.log
  To remove it again:
    sudo rm $SESSION_FILE
    rm -rf ~/.config/labwc$( [ -d "$LABWC_BACKUP" ] && printf ' && mv "%s" ~/.config/labwc' "$LABWC_BACKUP" )

EOF
