# setupde: labwc desktop for Void Linux

This turns a fresh (or nearly fresh) Void Linux install into a full, good-looking
desktop based on the [labwc](https://labwc.github.io) Wayland compositor. Everything
uses one dark colour theme (Catppuccin Mocha).

| Part            | Program                                             |
|-----------------|-----------------------------------------------------|
| Compositor      | labwc (+ Xwayland for X11 apps)                     |
| Panel           | Waybar: launcher, workspaces, taskbar, clock, tray, volume, brightness, network, battery, power |
| App launcher    | fuzzel                                              |
| Terminal        | foot                                                |
| Notifications   | mako                                                |
| Lock / idle     | swaylock + swayidle (locks after 5 min, screen off after 10 min) |
| Wallpaper       | swaybg                                              |
| Night light     | wlsunset (warmer colours from 20:00 to 07:00)       |
| Audio           | PipeWire + WirePlumber (pavucontrol for settings)   |
| Network         | NetworkManager + nm-applet                          |
| Bluetooth       | bluez + blueman                                     |
| Files           | Thunar (+ gvfs, udisks2, thumbnails, archives)      |
| Screenshots     | grim + slurp (+ swappy for annotating)              |
| Clipboard       | cliphist history (Super+V)                          |
| Login screen    | greetd + tuigreet                                   |
| Settings GUIs   | wdisplays (monitors), nwg-look (GTK theme), pavucontrol |
| Apps            | Firefox, Mousepad, imv (images), mpv (video)        |
| Look            | Adwaita-dark GTK, Papirus-Dark icons, Inter + Noto + Nerd Font symbols |

## Before you start

You need a working Void install with:

* a normal user account that can use `sudo` (the installer's "add user to wheel" option
  plus the `%wheel` line in `visudo`)
* a working internet connection
* `git` to clone this repo: `sudo xbps-install -S git`

Works with both glibc and musl.

**Graphics cards:** `install.sh` detects your GPU and installs the right driver:

* **AMD / Intel:** the open-source Mesa drivers, with Vulkan and video decoding
* **NVIDIA:** the proprietary `nvidia` driver from Void's nonfree repo (595.x, open kernel
  modules, so Turing / RTX 20 series or newer), with kernel modesetting turned on
  for Wayland. The modules are built with DKMS, so the first install takes a few minutes.
* **CPU graphics + NVIDIA card** (for example a Ryzen 7000 with an RTX card): labwc uses
  the NVIDIA card, where your monitor is plugged in. To use a different one, set
  `WLR_DRM_DEVICES=/dev/dri/cardN` in `/usr/local/bin/start-labwc`.

## Install

```sh
git clone https://github.com/kassudreams/setupde.git
cd setupde
./install.sh
sudo reboot
```

After the reboot you get a login screen. Log in and labwc starts.

### Options

```
./install.sh --layout=fi          # set the keyboard layout (default: KEYMAP from /etc/rc.conf)
./install.sh --no-greetd          # no login screen; log in on a TTY and run: start-labwc
./install.sh --no-bluetooth       # skip bluetooth
./install.sh --no-networkmanager  # keep dhcpcd / wpa_supplicant as they are
./install.sh --configs-only       # only (re)install the dotfiles + scripts
./install.sh -y                   # don't ask for confirmation
```

You can run the script again safely. Any of your config files it would overwrite get
backed up to `~/.config/setupde-backup-<date>/` first.

### What the installer changes on the system

* Updates the system, then installs the packages listed at the top of `install.sh`
* Enables these runit services: `dbus`, `NetworkManager`, `bluetoothd`, `greetd`.
  elogind is started on demand by dbus, not as its own service, because the two race at boot
* Disables `dhcpcd` and `wpa_supplicant` so NetworkManager can manage the network.
  **Your connection may drop near the end of the install.** Reconnect with `nmtui`,
  or with the tray icon once you're in labwc.
* Disables `seatd` and `acpid` if they're enabled, because they conflict with elogind
* Sets up PipeWire the Void way (`/etc/pipewire/pipewire.conf.d`, `/etc/alsa/conf.d`)
* Writes `/etc/greetd/config.toml` (the login screen runs on tty7, so tty1-6 still work)
* Adds your user to the `video`, `network` and `bluetooth` groups
* Copies the helper scripts to `/usr/local/bin`

## Gaming (optional)

After `install.sh`, run:

```sh
./gaming.sh
sudo reboot
```

This sets Void up for gaming, similar to CachyOS or PikaOS:

| What | Details |
|---|---|
| Steam + Proton | Enables the `nonfree` and `multilib` repos and installs Steam with all the 32-bit libraries it needs, plus the controller udev rules |
| GPU drivers | Detects your GPU. AMD gets RADV Vulkan (64 + 32-bit), VA-API and CoreCtrl. Intel gets ANV Vulkan and VA-API. NVIDIA gets the proprietary driver with 32-bit libraries and NVDEC video decoding |
| Game tools | gamemode, MangoHud (`Right Shift+F12` toggles it), gamescope, ProtonPlus (for GE-Proton), protontricks, Lutris, Wine + winetricks |
| Newer kernel | `linux-mainline` (7.x, fully preemptible, with sched_ext) becomes the default boot entry. The old kernel stays in GRUB as a fallback. **Skipped with NVIDIA**, because the driver may not build for the newest kernel yet. Use `--kernel` to install it anyway |
| CPU scheduler | `scx_lavd`, the gaming-focused sched_ext scheduler CachyOS offers, runs as a runit service. Change it in `/etc/sv/scx/conf` |
| Memory | zram compressed swap (`zramen`), and `earlyoom` so running out of RAM closes the biggest app instead of freezing the PC |
| Tweaks | `vm.max_map_count` raised (needed by many Proton games), split-lock slowdown turned off, best IO scheduler per disk, higher file limits for esync |
| Flatpak | Adds Flathub, for Heroic (Epic/GOG), Discord and other apps |

Options: `--no-kernel` keeps the default kernel, `--no-flatpak` skips Flatpak, `-y` doesn't ask for confirmation.

To use gamemode and MangoHud in Steam, set a game's launch options (right-click the game, then
Properties) to:

```
gamemoderun mangohud %command%
```

## Keyboard shortcuts

`Super` is the Windows key.

| Keys                         | Action                                   |
|------------------------------|------------------------------------------|
| `Super+Space` / `Super+R`    | App launcher                             |
| `Super+Enter`                | Terminal                                 |
| `Super+E`                    | File manager                             |
| `Super+B`                    | Firefox                                  |
| `Super+V`                    | Clipboard history                        |
| `Super+Q` / `Alt+F4`         | Close window                             |
| `Super+F`                    | Fullscreen                               |
| `Super+M` / `Super+A`        | Maximize                                 |
| `Super+H`                    | Minimize                                 |
| `Super+T`                    | Always on top                            |
| `Super+C`                    | Center window (80% size)                 |
| `Super+←/→/↑/↓`              | Snap to half of the screen               |
| `Super+Numpad 1-9`           | Snap to a quarter, half or center        |
| `Alt+Tab` / `Super+Tab`      | Switch windows                           |
| `Super+1..4`                 | Go to workspace 1-4                      |
| `Super+Shift+1..4`           | Move window to workspace 1-4             |
| `Super+Ctrl+←/→`             | Previous/next workspace                  |
| `Super+Shift+←/→`            | Move window to previous/next workspace   |
| `Super+D`                    | Show desktop                             |
| `Super+N`                    | Dismiss notifications                    |
| `Print`                      | Screenshot of an area                    |
| `Shift+Print`                | Screenshot of the whole screen           |
| `Ctrl+Print`                 | Screenshot of an area, then annotate it  |
| `Super+L`                    | Lock screen                              |
| `Super+Esc` / `Ctrl+Alt+Del` | Power menu (lock, log out, suspend, reboot, shut down) |
| `Super+Shift+R`              | Reload labwc config                      |
| `Super+Shift+E`              | Log out                                  |
| `Alt+Shift`                  | Switch keyboard layout (if you set two)  |

Mouse: left- or right-click the desktop for the menu, middle-click it for a window
list, scroll on it to switch workspaces. `Super+drag` moves a window and
`Super+right-drag` resizes it.

Screenshots are saved to `~/Pictures/Screenshots` and copied to the clipboard.

## Customising

All the configs live in `~/.config`:

| File                                  | What                                       |
|---------------------------------------|--------------------------------------------|
| `labwc/rc.xml`                        | Shortcuts, gaps, touchpad, workspaces      |
| `labwc/menu.xml`                      | Desktop right-click menu                   |
| `labwc/autostart`                     | What starts with the session               |
| `labwc/environment`                   | Keyboard layout, cursor, toolkit settings  |
| `labwc/themerc-override`              | Window border, titlebar and menu colours   |
| `waybar/config.jsonc`, `style.css`    | Panel                                      |
| `fuzzel/fuzzel.ini`                   | Launcher                                   |
| `foot/foot.ini`                       | Terminal                                   |
| `mako/config`                         | Notifications                              |
| `swaylock/config`                     | Lock screen                                |
| `kanshi/config`                       | Monitor resolution, refresh rate, scale    |

* **Wallpaper:** copy an image to `~/.config/labwc/wallpaper` (no file extension), then log out and back in.
* **Keyboard layout:** edit `XKB_DEFAULT_LAYOUT` in `~/.config/labwc/environment`.
  For two layouts use `us,fi`, then switch with `Alt+Shift`.
* **Monitors:** resolution, refresh rate and scale are set in `~/.config/kanshi/config`.
  The default is 3840x2160 at 119.88 Hz with 2.6 scaling. Use `wdisplays` to try out
  settings, then put the ones you want in the kanshi config so they stick.
* **Reload:** `Super+Shift+R` reloads the labwc files. Waybar and mako need a
  logout, or `pkill waybar; waybar &`.

## Troubleshooting

* **Boot hangs for a minute with `usb 1-12: device descriptor read/64, error -110`:**
  a USB device on that port isn't answering, and the kernel keeps retrying it. That's
  where the time goes. To fix it:
  1. Shut down and switch the PSU off for 30 seconds. Stuck devices, often the
     motherboard's internal Bluetooth, usually come back after this.
  2. Unplug USB devices one at a time, including hubs, dongles and RGB/AIO cables on
     internal headers, until the error goes away. If it's something you don't use,
     disable it in the BIOS.
  3. If it can't be fixed, make each retry shorter by adding
     `usbcore.initial_descriptor_timeout=1000` to `GRUB_CMDLINE_LINUX_DEFAULT` in
     `/etc/default/grub`, then run `sudo update-grub`.
  `amdgpu ... Failed to detect connector` and `hub ... doesn't have any ports` are
  harmless.

* **labwc doesn't start:** look in `~/.local/state/labwc.log`. Check that your user is
  in the `video` group (`groups`), that the `dbus` service is running
  (`sudo sv status dbus`) and that elogind is running (`pgrep -a elogind`).
* **Console spam `elogind is already running as PID ...`:** the elogind runit service is
  enabled and racing dbus. Run `sudo rm /var/service/elogind` and reboot.
* **No sound:** run `wpctl status`. PipeWire starts from labwc's autostart, so it only
  runs inside the labwc session.
* **No network after the install:** run `nmtui` and connect again.
* **Screen sharing doesn't work in the browser:** make sure the `xdg-desktop-portal-wlr`
  package is installed, then log out and back in.
* **Login screen loops back:** switch to a TTY with `Ctrl+Alt+F2`, log in and run
  `start-labwc`. Any error appears in `~/.local/state/labwc.log`.
