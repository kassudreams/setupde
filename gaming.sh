#!/bin/bash
# setupde gaming - turn Void Linux into a gaming setup (in the spirit of CachyOS / PikaOS).
#
# Run as your normal user (NOT root), after install.sh:
#     ./gaming.sh
#
# Options:
#     -y, --yes        don't ask for confirmation
#     --no-kernel      keep the default kernel (no linux-mainline + sched_ext scheduler)
#     --kernel         install linux-mainline even with an NVIDIA GPU (off by default
#                      there, since the NVIDIA driver may not build for the newest kernel)
#     --no-flatpak     don't set up Flatpak / Flathub
#     -h, --help       show this help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

ASSUME_YES=0
WANT_KERNEL=1
KERNEL_FORCED=0
WANT_FLATPAK=1

# ---------------------------------------------------------------- packages
PKGS_GAMING=(
	steam steam-udev-rules
	gamemode MangoHud gamescope
	protonplus protontricks
	wine wine-mono wine-gecko winetricks lutris
	Vulkan-Tools
	zramen earlyoom
)
# 32-bit libraries Steam and Proton need (from the multilib repo)
PKGS_32BIT=(
	libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit
	mesa-dri-32bit vulkan-loader-32bit libpulseaudio-32bit
	libgamemode-32bit MangoHud-32bit
)
PKGS_AMD=(mesa-vulkan-radeon mesa-vulkan-radeon-32bit mesa-vaapi corectrl radeontop)
PKGS_INTEL=(mesa-vulkan-intel mesa-vulkan-intel-32bit intel-video-accel)
PKGS_NVIDIA=(nvidia nvidia-libs-32bit linux-headers nvidia-vaapi-driver)
PKGS_KERNEL=(linux-mainline scx)

# ---------------------------------------------------------------- helpers
c_blue=$'\e[1;34m'; c_yellow=$'\e[1;33m'; c_red=$'\e[1;31m'; c_off=$'\e[0m'
step() { printf '\n%s==>%s %s\n' "$c_blue" "$c_off" "$*"; }
warn() { printf '%s!!%s  %s\n' "$c_yellow" "$c_off" "$*"; }
die()  { printf '%sxx%s  %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# xbps-install exits 17 when everything asked for is already installed
xbps() {
	local rc=0
	sudo xbps-install "$@" || rc=$?
	[ "$rc" -eq 0 ] || [ "$rc" -eq 17 ] || die "xbps-install failed (exit $rc)"
}

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

# Detect GPU vendors from sysfs: prints amd / intel / nvidia (one per line)
detect_gpus() {
	local v
	for v in /sys/class/drm/card*/device/vendor; do
		[ -r "$v" ] || continue
		case "$(cat "$v")" in
			0x1002) echo amd ;;
			0x8086) echo intel ;;
			0x10de) echo nvidia ;;
		esac
	done | sort -u
}

# ---------------------------------------------------------------- args
for arg in "$@"; do
	case "$arg" in
		-y|--yes) ASSUME_YES=1 ;;
		--no-kernel) WANT_KERNEL=0 ;;
		--kernel) WANT_KERNEL=1; KERNEL_FORCED=1 ;;
		--no-flatpak) WANT_FLATPAK=0 ;;
		-h|--help) usage ;;
		*) die "unknown option: $arg (see --help)" ;;
	esac
done

# ---------------------------------------------------------------- checks
[ "$(id -u)" -ne 0 ] || die "run this as your normal user, not root (it uses sudo when needed)"
command -v xbps-install >/dev/null || die "this script is for Void Linux (xbps-install not found)"
[ "$(xbps-uhelper arch)" = x86_64 ] ||
	die "Steam needs 64-bit glibc Void (x86_64). This system is $(xbps-uhelper arch)."

GPUS="$(detect_gpus | tr '\n' ' ')"
HAS_NVIDIA=0
case " $GPUS " in *" nvidia "*) HAS_NVIDIA=1 ;; esac

# The NVIDIA driver is an out-of-tree module (DKMS) that often lags behind
# the newest kernel, so keep the default kernel unless asked otherwise.
if [ "$HAS_NVIDIA" -eq 1 ] && [ "$KERNEL_FORCED" -eq 0 ]; then
	WANT_KERNEL=0
fi

cat <<EOF

  setupde gaming
  --------------
  GPU(s) found:      ${GPUS:-none detected}
  Steam + Proton, Lutris, Wine, gamemode, MangoHud, gamescope, ProtonPlus
  zram swap, earlyoom, gaming sysctl/IO/limit tweaks
  linux-mainline + scx_lavd scheduler: $( [ "$WANT_KERNEL" -eq 1 ] && echo yes || echo no )
  Flatpak + Flathub: $( [ "$WANT_FLATPAK" -eq 1 ] && echo yes || echo no )

EOF

if [ "$HAS_NVIDIA" -eq 1 ] && [ "$WANT_KERNEL" -eq 0 ] && [ "$KERNEL_FORCED" -eq 0 ]; then
	warn "NVIDIA GPU: keeping the default kernel so the NVIDIA driver keeps working."
	warn "(Use --kernel to install linux-mainline + scx_lavd anyway.)"
fi

if [ "$ASSUME_YES" -eq 0 ]; then
	read -r -p "Continue? [Y/n] " ans
	case "$ans" in [nN]*) exit 0 ;; esac
fi

sudo -v

# ---------------------------------------------------------------- repos
step "Enabling the nonfree and multilib (32-bit) repositories"
xbps -Sy void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
xbps -Syu xbps
xbps -yu

# ---------------------------------------------------------------- packages
pkgs=("${PKGS_GAMING[@]}" "${PKGS_32BIT[@]}")
case " $GPUS " in *" amd "*)   pkgs+=("${PKGS_AMD[@]}") ;; esac
case " $GPUS " in *" intel "*) pkgs+=("${PKGS_INTEL[@]}") ;; esac
[ "$HAS_NVIDIA" -eq 1 ]   && pkgs+=("${PKGS_NVIDIA[@]}")
[ "$WANT_KERNEL" -eq 1 ]  && pkgs+=("${PKGS_KERNEL[@]}")
# DKMS needs headers for every installed kernel
[ "$WANT_KERNEL" -eq 1 ] && [ "$HAS_NVIDIA" -eq 1 ] && pkgs+=(linux-mainline-headers)
[ "$WANT_FLATPAK" -eq 1 ] && pkgs+=(flatpak)

# Skip anything the repos don't have (instead of failing the whole install)
step "Checking packages"
avail=()
for p in "${pkgs[@]}"; do
	if xbps-query -R "$p" >/dev/null 2>&1; then
		avail+=("$p")
	else
		warn "package $p is not in the repositories, skipping it"
	fi
done

if [ "$HAS_NVIDIA" -eq 1 ] && [ ! -e /etc/modprobe.d/nvidia-drm.conf ]; then
	# Kernel modesetting is required for Wayland (install.sh normally does this)
	sudo mkdir -p /etc/modprobe.d
	echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia-drm.conf >/dev/null
fi

step "Installing gaming packages (this is a big download)"
xbps -y "${avail[@]}"

# With NVIDIA, the newest kernel is only safe if the driver built for it.
# Otherwise it would boot to a black screen, so take it out again.
if [ "$WANT_KERNEL" -eq 1 ] && [ "$HAS_NVIDIA" -eq 1 ]; then
	step "Checking that the NVIDIA driver built for linux-mainline"
	mainline_pkg="$(xbps-query -x linux-mainline 2>/dev/null | sed -n 's/^\(linux[0-9.]*\)>=.*/\1/p' | head -n1)"
	kver=""
	[ -n "$mainline_pkg" ] && kver="$(xbps-query -f "$mainline_pkg" 2>/dev/null |
		sed -n 's|^/usr/lib/modules/\([^/]*\)/.*|\1|p' | head -n1)"
	if [ -n "$kver" ] && ! find "/usr/lib/modules/$kver" -name 'nvidia.ko*' 2>/dev/null | grep -q .; then
		sudo dkms autoinstall -k "$kver" || true
	fi
	if [ -n "$kver" ] && find "/usr/lib/modules/$kver" -name 'nvidia.ko*' 2>/dev/null | grep -q .; then
		echo "    NVIDIA driver is built for $kver"
	else
		warn "The NVIDIA driver could not be built for ${kver:-linux-mainline}."
		warn "Removing linux-mainline again so you don't boot to a black screen."
		sudo xbps-remove -Ry linux-mainline linux-mainline-headers || true
		WANT_KERNEL=0
	fi
fi

# ---------------------------------------------------------------- tweaks
step "Installing system tweaks"
sudo install -m 644 "$REPO_DIR/system/99-gaming.conf"        /etc/sysctl.d/99-gaming.conf
sudo install -m 644 "$REPO_DIR/system/60-ioschedulers.rules" /etc/udev/rules.d/60-ioschedulers.rules
sudo mkdir -p /etc/security/limits.d
sudo install -m 644 "$REPO_DIR/system/99-gaming-limits.conf" /etc/security/limits.d/99-gaming-limits.conf
echo "    /etc/sysctl.d/99-gaming.conf"
echo "    /etc/udev/rules.d/60-ioschedulers.rules"
echo "    /etc/security/limits.d/99-gaming-limits.conf"
# Apply the sysctls now (some keys may not exist on every kernel, that's fine)
sudo sysctl -q -p /etc/sysctl.d/99-gaming.conf 2>/dev/null || true
sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=block --action=change || true

step "Enabling services"
enable_sv zramen    # compressed swap in RAM
enable_sv earlyoom  # kills the biggest app instead of freezing when RAM runs out

if [ "$WANT_KERNEL" -eq 1 ]; then
	sudo mkdir -p /etc/sv/scx
	sudo install -m 755 "$REPO_DIR/system/sv/scx/run" /etc/sv/scx/run
	[ -e /etc/sv/scx/conf ] || sudo install -m 644 "$REPO_DIR/system/sv/scx/conf" /etc/sv/scx/conf
	enable_sv scx
fi

step "Adding $USER to the gamemode group"
getent group gamemode >/dev/null && sudo usermod -aG gamemode "$USER"

step "Installing MangoHud config"
mkdir -p "$CONFIG_HOME/MangoHud"
if [ -e "$CONFIG_HOME/MangoHud/MangoHud.conf" ]; then
	echo "    keeping your existing ~/.config/MangoHud/MangoHud.conf"
else
	cp "$REPO_DIR/config-gaming/MangoHud/MangoHud.conf" "$CONFIG_HOME/MangoHud/"
	echo "    ~/.config/MangoHud/MangoHud.conf"
fi

if [ "$WANT_FLATPAK" -eq 1 ] && command -v flatpak >/dev/null; then
	step "Adding the Flathub app store"
	sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

cat <<EOF

${c_blue}Gaming setup done!${c_off}  Reboot to use everything:  sudo reboot
EOF
if [ "$WANT_KERNEL" -eq 1 ]; then
	cat <<'EOF'

  The new kernel (linux-mainline) is now the default boot entry. Your old
  kernel stays in GRUB under "Advanced options" in case you need it.
  Check the scheduler after rebooting:  cat /sys/kernel/sched_ext/root/ops
EOF
fi
cat <<'EOF'

  Steam:      enable Proton for all games in Settings > Compatibility.
  Per game:   right-click > Properties > Launch options, e.g.
                gamemoderun mangohud %command%
              (gamescope -f -- %command%  for a fullscreen gamescope session)
  GE-Proton:  open ProtonPlus to install GE-Proton / other Proton builds.
  Overlay:    Right Shift + F12 toggles MangoHud in-game.
EOF
if [ "$WANT_FLATPAK" -eq 1 ]; then
	cat <<'EOF'
  More apps:  flatpak install flathub com.heroicgameslauncher.hgl   (Epic/GOG)
              flatpak install flathub com.discordapp.Discord
EOF
fi
echo
