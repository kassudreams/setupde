# Shared parts of the PikaOS installers: pikaos-hyprland/install.sh and
# pikaos-labwc/install.sh. Sourced by them, not run on its own.
# The installer sets REPO_DIR, CONFIG_HOME and BACKUP_DIR before sourcing it.

c_blue=$'\e[1;34m'; c_yellow=$'\e[1;33m'; c_red=$'\e[1;31m'; c_off=$'\e[0m'
step() { printf '\n%s==>%s %s\n' "$c_blue" "$c_off" "$*"; }
warn() { printf '%s!!%s  %s\n' "$c_yellow" "$c_off" "$*"; }
die()  { printf '%sxx%s  %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }

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

# Keyboard layout: PikaOS's / our Hyprland config, our labwc config, then the
# system setting
detect_layout() {
	local l=""
	if [ -d "$CONFIG_HOME/hypr" ]; then
		l="$(grep -rhoE 'kb_layout[[:space:]]*=[[:space:]]*"[^"]*"' "$CONFIG_HOME/hypr" 2>/dev/null |
			head -n1 | sed 's/.*"\(.*\)"/\1/' || true)"
	fi
	if { [ -z "$l" ] || [ "$l" = "@KB_LAYOUT@" ]; } && [ -f "$CONFIG_HOME/labwc/environment" ]; then
		l="$(sed -n 's/^XKB_DEFAULT_LAYOUT=//p' "$CONFIG_HOME/labwc/environment" | head -n1 || true)"
	fi
	if [ -z "$l" ] || [ "$l" = "@KB_LAYOUT@" ]; then
		l="$(localectl status 2>/dev/null | sed -n 's/.*X11 Layout:[[:space:]]*//p' | head -n1 || true)"
	fi
	echo "${l:-us}"
}

# apt: install the packages that exist in the repos, skip (and say) the rest
install_packages() {
	sudo -v
	step "Updating package lists"
	sudo apt-get update

	step "Checking packages"
	local avail=() p
	for p in "$@"; do
		if apt-cache show "$p" >/dev/null 2>&1; then
			avail+=("$p")
		else
			warn "package $p is not available, skipping it"
		fi
	done

	step "Installing packages"
	sudo apt-get install -y "${avail[@]}"
}

# A polkit agent for password prompts, if PikaOS doesn't already have one
install_polkit_agent() {
	if ! ls /usr/lib/hyprpolkitagent/hyprpolkitagent /usr/libexec/hyprpolkitagent \
	        /usr/libexec/polkit-mate-authentication-agent-1 \
	        /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 \
	        /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 \
	        /usr/bin/lxpolkit >/dev/null 2>&1; then
		local agent
		for agent in hyprpolkitagent mate-polkit lxpolkit; do
			if apt-cache show "$agent" >/dev/null 2>&1; then
				sudo apt-get install -y "$agent" && break
			fi
		done
	fi
	return 0
}

# Icons in the panel come from the Nerd Fonts symbols font
install_symbols_font() {
	if ! fc-list 2>/dev/null | grep -qi 'Symbols Nerd Font'; then
		step "Installing the Nerd Fonts symbols font"
		local tmp
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
}

# Helper scripts from bin/ to /usr/local/bin
install_scripts() {
	step "Installing helper scripts to /usr/local/bin"
	local f
	for f in "$@"; do
		sudo install -m 755 "$REPO_DIR/bin/$f" /usr/local/bin/
		echo "    $f"
	done
}

# fuzzel, foot, mako, swaylock, GTK and the panel; the same for both desktops
install_app_configs() {
	step "Installing app configs and the panel (the same for labwc and Hyprland)"
	local rel
	for rel in fuzzel/fuzzel.ini foot/foot.ini mako/config swaylock/config gtk-3.0/settings.ini; do
		install_file "$REPO_DIR/config/$rel" "$CONFIG_HOME/$rel"
		echo "    $rel"
	done

	# Waybar: PikaOS layout (dock in the middle, hardware info, clock on the right)
	local wb="$REPO_DIR/pikaos-hyprland/waybar"
	install_file "$wb/style.css" "$CONFIG_HOME/waybar/style.css"
	# CPU temperature sensor: AMD k10temp / Intel coretemp, else the first thermal zone
	local cpu_temp='"thermal-zone": 0,' hw dev tmp_cfg
	for hw in /sys/class/hwmon/hwmon*; do
		case "$(cat "$hw/name" 2>/dev/null)" in
			k10temp|coretemp|zenpower)
				dev="$(readlink -f "$hw/device")"
				cpu_temp="\"hwmon-path-abs\": \"$dev/hwmon\", \"input-filename\": \"temp1_input\","
				break ;;
		esac
	done
	tmp_cfg="$(mktemp)"
	sed "s|@CPU_TEMP_SOURCE@|$cpu_temp|" "$wb/config.jsonc" > "$tmp_cfg"
	install_file "$tmp_cfg" "$CONFIG_HOME/waybar/config.jsonc"
	rm -f "$tmp_cfg"
	echo "    waybar/config.jsonc, waybar/style.css"

	# The panel's network icon has its own menu, so keep nm-applet / blueman out
	# of the tray if the system would autostart them
	local app
	for app in nm-applet blueman; do
		if [ -f "/etc/xdg/autostart/$app.desktop" ]; then
			mkdir -p "$CONFIG_HOME/autostart"
			printf '[Desktop Entry]\nHidden=true\n' > "$CONFIG_HOME/autostart/$app.desktop"
		fi
	done

	# Dock: default pinned apps on first install, then generate it
	command -v setupde-dock >/dev/null && setupde-dock build >/dev/null 2>&1 || true

	# Let the panel read CPU power (RAPL energy counter is root-only by default).
	# Note: this also lets programs estimate CPU activity from power use; remove
	# /etc/tmpfiles.d/setupde-rapl.conf if that matters to you.
	if [ -e /sys/class/powercap/intel-rapl:0/energy_uj ]; then
		echo 'z /sys/class/powercap/intel-rapl:0/energy_uj 0444 root root -' |
			sudo tee /etc/tmpfiles.d/setupde-rapl.conf >/dev/null
		sudo systemd-tmpfiles --create /etc/tmpfiles.d/setupde-rapl.conf 2>/dev/null || true
		echo "    CPU power readable by the panel (/etc/tmpfiles.d/setupde-rapl.conf)"
	fi
	# GParted runs as root, so it doesn't see our dark mode setting. Give root's
	# GTK the same settings (only if root has none of its own yet)
	if command -v gparted >/dev/null && ! sudo test -e /root/.config/gtk-3.0/settings.ini; then
		sudo install -D -m 644 "$REPO_DIR/config/gtk-3.0/settings.ini" /root/.config/gtk-3.0/settings.ini
		echo "    GParted in dark mode (/root/.config/gtk-3.0/settings.ini)"
	fi
	install_file "$REPO_DIR/config/gtk-3.0/settings.ini" "$CONFIG_HOME/gtk-4.0/settings.ini"
	# Guix programs (e.g. IceCat) use their own fontconfig; point it at the system fonts
	install_file "$REPO_DIR/pikaos-hyprland/fontconfig/10-setupde-system-fonts.conf" \
		"$CONFIG_HOME/fontconfig/conf.d/10-setupde-system-fonts.conf"

	if command -v gsettings >/dev/null; then
		gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
		gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true
		gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark 2>/dev/null || true
		gsettings set org.gnome.desktop.interface cursor-theme Adwaita 2>/dev/null || true
		gsettings set org.gnome.desktop.interface font-name 'Inter 10' 2>/dev/null || true
	fi
	mkdir -p "$HOME/Pictures/Screenshots"
	[ -d "$BACKUP_DIR" ] && warn "replaced app configs were backed up to $BACKUP_DIR"
	return 0
}

# PikaOS's own shell (otter-shell: panel, launcher, notifications) and its idle
# locker (hypridle -> hyprlock) would run next to ours (waybar, mako, swayidle
# -> swaylock). Two lockers fight over the screen, and hyprlock without its
# PikaOS config shows only a background picture with no password box.
pikaos_shell_off() {
	local units u f
	units="$(systemctl --user list-unit-files 2>/dev/null | awk '{print $1}' |
		grep -i -E 'otter|hypridle|hyprlock' || true)"
	if [ -n "$units" ]; then
		step "Turning off PikaOS's shell and idle locker (ours replace them)"
		for u in $units; do
			systemctl --user disable --now "$u" 2>/dev/null || true
			echo "    disabled $u   (undo: systemctl --user enable --now $u)"
		done
	fi
	for f in /etc/xdg/autostart/*otter*.desktop /etc/xdg/autostart/*hypridle*.desktop \
	         /etc/xdg/autostart/*hyprlock*.desktop; do
		[ -f "$f" ] || continue
		mkdir -p "$CONFIG_HOME/autostart"
		printf '[Desktop Entry]\nHidden=true\n' > "$CONFIG_HOME/autostart/$(basename "$f")"
		echo "    hid autostart entry $(basename "$f")   (undo: rm ~/.config/autostart/$(basename "$f"))"
	done
	pkill -x hypridle 2>/dev/null || true

	# PikaOS's otter-idle locks with otter-lock (a moving picture screensaver)
	# after 5 minutes, racing our swaylock. Switch its timers off and make it use
	# swaylock if anything still starts it.
	local otter_idle="$CONFIG_HOME/otter-shell/otter-idle.conf"
	if [ -f "$otter_idle" ]; then
		# keep the original next to the other backups
		mkdir -p "$BACKUP_DIR/.config/otter-shell"
		cp -n "$otter_idle" "$BACKUP_DIR/.config/otter-shell/otter-idle.conf" 2>/dev/null || true
		sed -i -E \
			-e 's/^(listener_[0-9]+_timeout)[[:space:]]*=.*/\1 = 0/' \
			-e 's/^lock_cmd[[:space:]]*=.*/lock_cmd = "pidof swaylock || swaylock -f"/' \
			"$otter_idle"
		echo "    otter-idle: timers off, locks with swaylock (~/.config/otter-shell/otter-idle.conf)"
	fi
	pkill -x otter-idle 2>/dev/null || true
}
