#!/bin/bash
# setupde - labwc desktop for a (nearly) fresh Void Linux install.
#
# Run as your normal user (NOT root), from this directory:
#     ./install.sh
#
# Options:
#     -y, --yes            don't ask for confirmation
#     --layout=XX          keyboard layout, e.g. us, fi, de, gb  (default: from /etc/rc.conf)
#     --no-greetd          don't install the graphical login (start with `start-labwc` on a TTY)
#     --no-bluetooth       skip bluez/blueman
#     --no-networkmanager  keep your current networking (dhcpcd / wpa_supplicant)
#     --configs-only       only copy the dotfiles + scripts, don't touch packages/services
#     -h, --help           show this help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$CONFIG_HOME/setupde-backup-$(date +%Y%m%d-%H%M%S)"

ASSUME_YES=0
LAYOUT=""
WANT_GREETD=1
WANT_BLUETOOTH=1
WANT_NM=1
CONFIGS_ONLY=0

# ---------------------------------------------------------------- packages
PKGS_CORE=(
	labwc xorg-server-xwayland mesa-dri
	Waybar fuzzel foot mako swaybg swaylock swayidle wlopm wlsunset
	grim slurp swappy wl-clipboard cliphist brightnessctl playerctl libnotify
	wlr-randr kanshi wdisplays nwg-look
)
PKGS_SESSION=(
	dbus elogind polkit polkit-gnome
	xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
	xdg-user-dirs xdg-utils qt5-wayland qt6-wayland
)
PKGS_AUDIO=(pipewire wireplumber alsa-pipewire pavucontrol)
PKGS_APPS=(
	Thunar thunar-volman thunar-archive-plugin xarchiver gvfs udisks2 tumbler
	firefox mousepad imv mpv unzip p7zip
)
PKGS_LOOK=(
	font-inter noto-fonts-ttf noto-fonts-emoji dejavu-fonts-ttf
	nerd-fonts-symbols-ttf font-awesome6
	papirus-icon-theme adwaita-icon-theme gnome-themes-extra
)
PKGS_NM=(NetworkManager network-manager-applet)
PKGS_BT=(bluez blueman libspa-bluetooth)
PKGS_GREETD=(greetd tuigreet)

# ---------------------------------------------------------------- helpers
c_blue=$'\e[1;34m'; c_yellow=$'\e[1;33m'; c_red=$'\e[1;31m'; c_off=$'\e[0m'
step() { printf '\n%s==>%s %s\n' "$c_blue" "$c_off" "$*"; }
warn() { printf '%s!!%s  %s\n' "$c_yellow" "$c_off" "$*"; }
die()  { printf '%sxx%s  %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

enable_sv() {
	local sv="$1"
	[ -d "/etc/sv/$sv" ] || { warn "service $sv not found, skipping"; return; }
	if [ -e "/var/service/$sv" ]; then
		echo "    service $sv already enabled"
	else
		sudo ln -s "/etc/sv/$sv" /var/service/
		echo "    enabled service $sv"
	fi
}

# xbps-install exits 17 when everything asked for is already installed
xbps() {
	local rc=0
	sudo xbps-install "$@" || rc=$?
	[ "$rc" -eq 0 ] || [ "$rc" -eq 17 ] || die "xbps-install failed (exit $rc)"
}

disable_sv() {
	local sv="$1"
	if [ -e "/var/service/$sv" ]; then
		sudo rm "/var/service/$sv"
		echo "    disabled service $sv"
	fi
}

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

detect_layout() {
	local km=""
	if [ -r /etc/rc.conf ]; then
		km="$(sed -n 's/^[[:space:]]*KEYMAP=["'\'']\{0,1\}\([^"'\'' ]*\).*/\1/p' /etc/rc.conf | tail -n1)"
	fi
	km="${km%%-*}"; km="${km%%_*}"
	case "$km" in
		uk) km=gb ;;
		dvorak*|"") km=us ;;
	esac
	echo "$km"
}

# ---------------------------------------------------------------- args
for arg in "$@"; do
	case "$arg" in
		-y|--yes) ASSUME_YES=1 ;;
		--layout=*) LAYOUT="${arg#*=}" ;;
		--no-greetd) WANT_GREETD=0 ;;
		--no-bluetooth) WANT_BLUETOOTH=0 ;;
		--no-networkmanager) WANT_NM=0 ;;
		--configs-only) CONFIGS_ONLY=1 ;;
		-h|--help) usage ;;
		*) die "unknown option: $arg (see --help)" ;;
	esac
done

# ---------------------------------------------------------------- checks
[ "$(id -u)" -ne 0 ] || die "run this as your normal user, not root (it uses sudo when needed)"
command -v xbps-install >/dev/null || die "this script is for Void Linux (xbps-install not found)"
command -v sudo >/dev/null || die "sudo is required (as root: xbps-install sudo; visudo to allow the wheel group)"

[ -n "$LAYOUT" ] || LAYOUT="$(detect_layout)"

cat <<EOF

  setupde: labwc desktop for Void Linux
  -------------------------------------
  user:            $USER
  keyboard layout: $LAYOUT
  packages:        $( [ "$CONFIGS_ONLY" -eq 1 ] && echo no || echo yes )
  NetworkManager:  $( [ "$WANT_NM" -eq 1 ] && echo yes || echo no )
  bluetooth:       $( [ "$WANT_BLUETOOTH" -eq 1 ] && echo yes || echo no )
  greetd login:    $( [ "$WANT_GREETD" -eq 1 ] && echo yes || echo no )
  configs go to:   $CONFIG_HOME  (existing files are backed up first)

EOF

if [ "$ASSUME_YES" -eq 0 ]; then
	read -r -p "Continue? [Y/n] " ans
	case "$ans" in [nN]*) exit 0 ;; esac
fi

# ---------------------------------------------------------------- packages
if [ "$CONFIGS_ONLY" -eq 0 ]; then
	sudo -v

	step "Updating the system"
	xbps -Syu xbps
	xbps -yu

	pkgs=("${PKGS_CORE[@]}" "${PKGS_SESSION[@]}" "${PKGS_AUDIO[@]}" "${PKGS_APPS[@]}" "${PKGS_LOOK[@]}")
	[ "$WANT_NM" -eq 1 ]        && pkgs+=("${PKGS_NM[@]}")
	[ "$WANT_BLUETOOTH" -eq 1 ] && pkgs+=("${PKGS_BT[@]}")
	[ "$WANT_GREETD" -eq 1 ]    && pkgs+=("${PKGS_GREETD[@]}")

	step "Installing packages"
	xbps -y "${pkgs[@]}"

	step "Enabling base services"
	enable_sv dbus
	enable_sv elogind
	# elogind and these conflict over seats / power keys
	for sv in seatd acpid; do
		if [ -e "/var/service/$sv" ]; then
			warn "$sv is enabled and conflicts with elogind - disabling it"
			disable_sv "$sv"
		fi
	done

	step "Configuring PipeWire (audio)"
	sudo mkdir -p /etc/pipewire/pipewire.conf.d /etc/alsa/conf.d
	sudo ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
	sudo ln -sf /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
	sudo ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
	sudo ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
	if [ -e /var/service/pulseaudio ]; then
		warn "pulseaudio system service found - disabling it (PipeWire replaces it)"
		disable_sv pulseaudio
	fi

	if [ "$WANT_BLUETOOTH" -eq 1 ]; then
		step "Enabling bluetooth"
		enable_sv bluetoothd
		sudo usermod -aG bluetooth "$USER" || true
	fi

	step "Adding $USER to groups"
	for g in video network; do
		getent group "$g" >/dev/null && sudo usermod -aG "$g" "$USER"
	done

fi

# ---------------------------------------------------------------- scripts + dotfiles
step "Installing helper scripts to /usr/local/bin"
for f in "$REPO_DIR"/bin/*; do
	sudo install -m 755 "$f" /usr/local/bin/
	echo "    $(basename "$f")"
done

step "Installing configs into $CONFIG_HOME"
while IFS= read -r -d '' src; do
	rel="${src#"$REPO_DIR"/config/}"
	install_file "$src" "$CONFIG_HOME/$rel"
	echo "    $rel"
done < <(find "$REPO_DIR/config" -type f -print0 | sort -z)
chmod +x "$CONFIG_HOME/labwc/autostart" "$CONFIG_HOME/labwc/shutdown"

if [ ! -e "/usr/share/X11/xkb/symbols/${LAYOUT%%,*}" ]; then
	warn "keyboard layout '$LAYOUT' not found in xkb, falling back to 'us'"
	LAYOUT=us
fi
sed -i "s/^XKB_DEFAULT_LAYOUT=.*/XKB_DEFAULT_LAYOUT=$LAYOUT/" "$CONFIG_HOME/labwc/environment"
echo "    keyboard layout set to $LAYOUT (edit ~/.config/labwc/environment to change)"

# GTK4 apps read the colour scheme from gsettings; also keep a gtk-4.0 ini
mkdir -p "$CONFIG_HOME/gtk-4.0"
install_file "$REPO_DIR/config/gtk-3.0/settings.ini" "$CONFIG_HOME/gtk-4.0/settings.ini"
if command -v gsettings >/dev/null; then
	gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
	gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true
	gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark 2>/dev/null || true
	gsettings set org.gnome.desktop.interface cursor-theme Adwaita 2>/dev/null || true
	gsettings set org.gnome.desktop.interface font-name 'Inter 10' 2>/dev/null || true
fi

command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update
mkdir -p "$HOME/Pictures/Screenshots"

[ -d "$BACKUP_DIR" ] && warn "your previous configs were backed up to $BACKUP_DIR"

# ---------------------------------------------------------------- network + login (last: these take effect immediately)
if [ "$CONFIGS_ONLY" -eq 0 ]; then
	if [ "$WANT_NM" -eq 1 ]; then
		step "Switching networking to NetworkManager"
		if [ -e /var/service/dhcpcd ] || [ -e /var/service/wpa_supplicant ]; then
			warn "dhcpcd/wpa_supplicant are being disabled - your connection may drop now."
			warn "Reconnect afterwards with:  nmtui   (or the tray icon once in labwc)"
		fi
		disable_sv dhcpcd
		disable_sv wpa_supplicant
		enable_sv NetworkManager
	fi

	if [ "$WANT_GREETD" -eq 1 ]; then
		step "Setting up greetd + tuigreet login screen (on tty7)"
		sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
# greetd config - written by setupde
[terminal]
vt = 7

[default_session]
command = "tuigreet --time --remember --asterisks --greeting 'Welcome to Void Linux' --cmd start-labwc"
user = "_greeter"
EOF
		sudo mkdir -p /var/cache/tuigreet
		sudo chown _greeter:_greeter /var/cache/tuigreet
	fi
fi

cat <<EOF

${c_blue}All done!${c_off}

  Reboot now:  sudo reboot
EOF
if [ "$WANT_GREETD" -eq 1 ] && [ "$CONFIGS_ONLY" -eq 0 ]; then
	echo "  You'll get a login screen; log in and labwc starts."
	# runit would start greetd right away and yank the console to tty7.
	# A 'down' file makes runsv leave it stopped now; once runsv has picked
	# it up we remove the file so greetd starts normally on the next boot.
	if [ ! -e /var/service/greetd ]; then
		sudo touch /etc/sv/greetd/down
		enable_sv greetd
		for _ in $(seq 20); do
			sudo sv status greetd 2>/dev/null | grep -q '^down' && break
			sleep 1
		done
		sudo rm -f /etc/sv/greetd/down
	fi
else
	echo "  Then log in on a TTY and run:  start-labwc"
fi
cat <<'EOF'

  Super+Space  launcher        Super+Enter  terminal     Super+E  files
  Super+Q      close window    Super+Esc    power menu   Print    screenshot
  Right-click the desktop for the menu. See README.md for all shortcuts.

  Want Steam and gaming tweaks too? Run ./gaming.sh next.

EOF
