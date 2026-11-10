# setupde: labwc desktop for Void Linux (+ PikaOS Hyprland and labwc)

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

## PikaOS Hyprland

The same look for **PikaOS's Hyprland edition** (Hyprland 0.55 or newer, which uses a Lua config)
is in [`pikaos-hyprland/`](pikaos-hyprland). It uses the same waybar, fuzzel, foot, mako and
lock screen configs, with soft shadows, blur and springy animations.

**How windows work:** every window floats, and "tiles" are windows snapped to a part of the screen
(like Windows). So clicking any window always brings it to the front, and nothing gets stuck behind
anything.

| Do this | What happens |
|---|---|
| Open an app | The first window on an empty workspace opens **big** (fills the screen below the panel). Later ones open at their own size, centred, and cascade. Every window fits below the panel. Games keep the size they ask for |
| `Super+←` / `Super+→` | Snap to the left / right half. Press again: 1/3, then 2/3 |
| `Super+↑` | Big. A half goes to its top quarter |
| `Super+↓` | Back to its own size. A half goes to its bottom quarter. A window at its own size is minimized |
| Drag to a screen edge and hold still a moment | Left/right edge: half. Top edge: big. Corner: quarter. Drag a snapped window away and it gets its own size back |
| `Super+T` | **Arrange**: tile every window on the workspace (2 = halves, 3 = half + quarters, 4 = quarters, more = grid). Press again to put them back |
| Double-click the title bar / `Super+M` | Big ↔ own size |
| Title bar buttons | Close, big/own size, minimize, snap menu (halves, quarters, Arrange) |
| Minimize (button, `Super+H`) | The window hides. Click it in the dock to bring it back |
| `Super+F1` | List of all shortcuts (also: right-click the launcher icon) |

Dragging snaps once the window rests at the edge for about 0.3 s: Hyprland can't tell a script when
the mouse button is let go. Dialogs open over their app and are left out of Arrange. Windows dragged
close to each other or to the panel snap together magnetically.

```sh
git clone https://github.com/kassudreams/setupde.git
cd setupde/pikaos-hyprland
./install.sh
```

Then log out and back in. What it does:

* Installs the apps with apt. Anything PikaOS doesn't have is skipped with a warning
* Moves your current `~/.config/hypr` to `~/.config/hypr.pikaos-backup-<date>` and installs the new
  config, keeping your keyboard layout
* Installs the hyprbars title-bar plugin: PikaOS's package if there is one, otherwise it builds it
  with `hyprpm` (installs Hyprland's build dependencies, takes a few minutes)
* Forces dark mode for GTK apps (Thunar, Lutris, ...) and keeps PikaOS's Qt theme setting
* Turns off PikaOS's otter-shell panel, since waybar and mako replace it (the installer prints how
  to turn it back on)
* Sets the monitor to 3840x2160 at 119.88 Hz with scale 2.666667, the closest scale to 2.6 that
  Hyprland accepts (edit `~/.config/hypr/monitors.lua`)
* Runs X11 apps at native resolution (`xwayland.force_zero_scaling`), so Wine/Proton games such as
  WoW see the full 3840x2160 while the desktop keeps its scale
* With an NVIDIA card next to CPU graphics, uses the NVIDIA card. It's detected at every start
* Drive tools: **Disks** (GNOME Disks: format drives and USB sticks, partition, write an image to
  a stick, check drive health) and **GParted** (resize and move partitions), with exFAT, NTFS and
  FAT support. Both are in the app launcher and ask for your password before changing a drive

Config files in `~/.config/hypr`: `monitors.lua`, `input.lua` (keyboard), `look.lua` (gaps,
borders, blur, animations), `snap.lua` (snapping, Arrange, big / own size), `windows.lua` (opening rules, minimize, blur on
panels), `game.lua` (game mode), `keybinds.lua`, `autostart.sh` (panel, tray, idle). Hyprland reloads the Lua files as soon as you save them.

**The panel** (PikaOS layout):

| Part | What it does |
|---|---|
| Left | launcher, workspaces |
| Middle | **dock**, pinned apps and open windows in one strip. A pinned app is a launcher while it's closed. While it runs, its windows appear as taskbar buttons with an indicator line: click to focus, middle-click to close, right-click to minimise. Right-click a launcher to unpin it, **+** (or `Super+Shift+Space`) pins an app from the app list. Order: `~/.config/setupde/dock.list`, then `setupde-dock build` |
| Right | tray, **CPU load + temperature, GPU load + temperature, memory, power draw**, night light, screen-awake toggle, volume, network, **clock + calendar**, power menu |

* **Power draw** adds CPU power (from the processor's RAPL energy counter) and GPU power
  (`nvidia-smi`). The rest of the PC isn't measured, so expect roughly 30-60 W more at the wall.
  The installer makes the RAPL counter readable with `/etc/tmpfiles.d/setupde-rapl.conf`
* **Night light** (moon icon): click for a popup with an on/off switch and **warmth** and
  **brightness** sliders, right-click to toggle. It uses `hyprsunset`, and brightness is a software
  dimmer, so it works on TVs too. Settings are remembered
* Clicking CPU opens `btop`, clicking GPU opens `nvtop`
* **Network** shows only a signal meter (or a wired icon). Click it for one list of every way online:
  Ethernet, a phone over USB (USB tethering) and Wi-Fi networks with their signal, plus Wi-Fi on/off
  and the full network settings. **Pick one to switch to it**: it connects (asking the password of a
  new Wi-Fi), then disconnects the others; VPNs aren't touched. `✓ in use` marks the one the
  internet goes through. Hover the icon for the network name, IP and speed. nm-applet is no longer
  in the tray
* **Sound output:** click the volume icon to choose where sound goes: the Genelecs, headphones,
  monitor speakers (HDMI/DisplayPort), Bluetooth, ... What's playing moves over right away.
  Scroll on the icon for volume, right-click mutes, middle-click opens the full sound settings.
  `setupde-audio next` switches to the next output (for a key, if you want one)
* **Mullvad VPN:** run `setupde-vpn install` once (adds Mullvad's apt repository, installs the app
  and asks for your account number). A lock next to the network icon shows the VPN: green with the
  country while connected, grey when off, red when internet is blocked. Click it for connect /
  disconnect, location (country and city), *connect when the computer starts*, *block internet when
  the VPN is off* and *allow local network*. Right-click connects or disconnects. The network menu
  has a VPN line too. To keep a game out of the VPN (lower ping, no VPN warnings), set Lutris →
  Configure → System options → *Command prefix* to `mullvad-exclude`
* **Phone over USB:** Android needs nothing extra. Plug it in, tap the USB notification on the phone
  and choose *USB tethering* (or Settings → Hotspot & tethering). NetworkManager connects it by itself
  and it takes over from Wi-Fi; Ethernet stays first while it's connected. To make the phone tether
  every time it's plugged in: Developer options → *Default USB configuration* → *USB tethering*.
  iPhone: tap *Trust*, then turn on Personal Hotspot (`usbmuxd`, installed by the installer, does
  the pairing). An iPhone's Wi-Fi hotspot only shows up while its Personal Hotspot screen is open;
  use *Scan for Wi-Fi again* in the menu

**HDR:** the monitor runs at 10-bit. HDR is on or off for the whole screen and apps never switch it
by themselves: **game mode (`Super+G`) turns HDR on, leaving game mode turns it off**. `setupde-hdr on`
keeps HDR on all the time, `setupde-hdr off` keeps it off (also in game mode), `setupde-hdr game`
goes back to the default. If HDR looks washed out, raise `sdrsaturation` (e.g. 1.15) and
`sdrbrightness` in `~/.config/hypr/monitors.lua`. On an LG TV, turn on *HDMI Ultra HD Deep Colour* for that input.
While HDR is on, normal (SDR) pictures are mapped into it. For real HDR the game has to send it:

* **Proton games:** launch options `PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_HDR=1 %command%`, then
  turn HDR on in the game. The other way is gamescope: `gamescope --hdr-enabled -W 3840 -H 2160 -r 120 -f -- %command%`
* **Videos:** `mpv --vo=gpu-next --target-colorspace-hint=yes file.mkv`

**GNU Guix next to PikaOS:** the config adds Guix's programs, app launchers (fuzzel and the dock),
language data and cursor themes to the session, and `~/.config/fontconfig/conf.d/10-setupde-system-fonts.conf`
lets Guix programs use the system fonts. Install Guix apps with `guix install <name>`, for example
`guix install icecat glibc-locales`, then log out and back in once.

**After PikaOS updates Hyprland** the title bars disappear until the plugin is rebuilt for the new
version. At login a notification says so when that happened: click it and a terminal rebuilds the
plugin (a few minutes, asks for your password). Or run `setupde-rebuild-plugins` yourself. It
first installs whatever the new Hyprland needs to build plugins (0.57 added libcanberra and sdbus-c++).

**Snapshots before updates:** run `setupde-snapshot setup` once. It installs Timeshift and from then
on takes a snapshot of the system before apt or PikaOS's updater changes anything (at most one every
3 hours, the newest 5 are kept). The first one copies the whole system and takes 5-15 minutes; later
ones only copy what changed. Your files in `/home` aren't in snapshots, and neither are Guix and
Flatpak apps, so going back to one never touches them. `setupde-snapshot list` shows them,
`setupde-snapshot now` takes one by hand, `setupde-snapshot remove` turns the automatic ones off.

**Going back after a bad update:** run `setupde-snapshot restore`. If the desktop doesn't start,
press `Ctrl+Alt+F3`, log in and run it there. Pick a snapshot by number and type `yes`; the PC
restarts when it's done. Snapshots include `/boot`, so the kernels match their drivers again, and
rEFInd finds them by itself. If the PC doesn't even get that far, pick an older kernel in the rEFInd
boot menu first (PikaOS keeps a few).

**Game mode:** `Super+G` turns off blur, shadows, animations and see-through inactive windows,
turns on VRR (G-Sync / FreeSync) for fullscreen windows and HDR for the whole screen, hides
notifications and pauses the night light. A green gamepad icon shows in the panel; click it or press `Super+G` again to go back.
To have it switch by itself for a game in Lutris: right-click the game → Configure → System options
→ *Pre-launch script* `setupde-gamemode on`, *Post-exit script* `setupde-gamemode off`.
If the screen flickers in games with VRR, set `vrr = 0` in `game_look()` in `~/.config/hypr/game.lua`.

Go back to PikaOS's setup with `rm -rf ~/.config/hypr && mv ~/.config/hypr.pikaos-backup-<date> ~/.config/hypr`.

## PikaOS labwc

The same desktop on **labwc** instead of Hyprland: [`pikaos-labwc/`](pikaos-labwc). labwc is simpler
and steadier than Hyprland. It does title bars, snapping, HDR and VRR itself, without plugins or
scripts. The panel (dock, hardware info, network, VPN and sound menus, night light, game mode),
launcher, terminal, notifications and lock screen are the same as in the Hyprland setup.
It's installed **next to** Hyprland. You pick one on the login screen, and Hyprland and its
config stay as they are.

```sh
cd setupde/pikaos-labwc
./install.sh
```

Then log out and choose **labwc (setupde)** on the login screen. Plain "labwc" starts it without HDR.
To go back to Hyprland, log out and choose Hyprland there. What the installer does:

* Installs labwc (0.20 or newer for HDR; PikaOS has 0.20.3) and what it needs: kanshi (monitor),
  gammastep (night light), swayidle + wlopm (lock and screen off), wlrctl (the dock), wdisplays.
  It also installs the same apps as the Hyprland setup
* Adds the login screen entry `/usr/share/wayland-sessions/setupde-labwc.desktop`, which runs
  `start-labwc`
* Moves an existing `~/.config/labwc` to `~/.config/labwc.backup-<date>` and installs the new config.
  Keyboard layout, Qt theme, wallpaper and monitor settings (resolution, refresh rate, scale) come
  from your Hyprland setup
* waybar, fuzzel, foot, mako, swaylock and GTK get the same config files as with the Hyprland
  installer, so both desktops look the same

Windows work like in the Hyprland setup:

| Do this | What happens |
|---|---|
| Open an app | It opens at its own size. New windows cascade |
| `Super+←` / `Super+→` | Snap to the left / right half |
| `Super+↑` | Big. A half goes to its top quarter, and a top quarter becomes big |
| `Super+↓` | Back to its own size. A half goes to its bottom quarter. A bottom quarter, or a window at its own size, is minimized |
| `Super+Alt+←` / `Super+Alt+→` | Left / right third. Press again to put it back |
| `Super+numpad 1-9` | That part of the screen (7 = top left quarter, 5 = middle, ...) |
| Drag to a screen edge and let go | Left/right edge: half. Top edge: big. Corner: quarter. A blue preview shows where it goes |
| Double-click the title bar / `Super+M` | Big ↔ own size |
| `Super+C` | Own size, centred |
| Minimize (button, `Super+H`) | Click it in the dock to bring it back |
| Desktop: right-click / middle-click | Menu / list of all windows |
| `Super+F1` | List of all shortcuts |

Not in labwc: Arrange (`Super+T`), blur and animations, and the first window doesn't open big by
itself (press `Super+↑`).

**HDR and VRR:** `start-labwc` starts labwc with the Vulkan renderer, which HDR needs. Like on
Hyprland, **game mode (`Super+G`) turns HDR on for the whole screen and leaving it turns HDR off**.
Game mode also hides notifications and pauses the night light. `setupde-hdr on|off|game` works as on
Hyprland, and it's one setting for both desktops. VRR (G-Sync / FreeSync) is always on for full screen
windows. If labwc can't start with the Vulkan renderer (that depends on the NVIDIA driver version),
it starts again with the normal one by itself, and game mode then says HDR isn't available. The logs
are `~/.local/state/labwc.log` and `labwc.log.vulkan`.

**Games:** labwc scales X11 apps up, so they look a bit soft (the Steam client, for example), and an
X11 game only sees a 1440x810 screen. Run Wine/Proton games with Wine's Wayland driver instead:
`PROTON_ENABLE_WAYLAND=1` (in Lutris: Configure → System options → Environment variables; WoW
already has it). Then the game gets the full 3840x2160, and HDR with `PROTON_ENABLE_HDR=1`. Known
labwc 0.20 problem: some Wine game windows disappear after Alt+Tab
([labwc #3615](https://github.com/labwc/labwc/pull/3615)). If that happens with a game, play it in
the Hyprland session.

Config files: `~/.config/labwc/rc.xml` (keys, snapping, HDR/VRR, title bars), `autostart` (panel,
idle, night light), `environment` (keyboard layout, dark mode), `themerc-override` (colours) and
`menu.xml` (desktop menu). `Super+Shift+R` reloads them. The monitor is set in `~/.config/kanshi/config`.
To remove the labwc desktop: `sudo rm /usr/share/wayland-sessions/setupde-labwc.desktop` and
`rm -rf ~/.config/labwc`.

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

### Games at full resolution with a scaled desktop

X11 games (Wine, Proton, Lutris, Battle.net, most of Steam) only see the *scaled* screen size.
At scale 2.6 a 4K monitor looks like 1477x831 to them, so 3840x2160 doesn't show up in the
game's settings. The fix is to switch to scale 1 while playing:

* **Manually:** `Super+F12` switches between scale 1 and your normal scale.
* **Automatically in Lutris:** right-click the game, choose *Configure*, then *System options*
  (turn on *Advanced* at the top) and set:
  * *Pre-launch script*: `/usr/local/bin/display-scale-native`
  * *Post-exit script*: `/usr/local/bin/display-scale-restore`
* **In Steam:** set the launch options to `display-scale 1; %command%; display-scale default`.

After switching to scale 1, pick 3840x2160 and fullscreen in the game's display settings.

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
| `Super+F12`                  | Toggle display scale between 1 and normal (for games) |
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

* **Wallpaper:** the installer sets `wallpapers/catppuccin-floaty.jpg`. To use your own, copy an image over
  `~/.config/labwc/wallpaper` (or `~/.config/hypr/wallpaper` on PikaOS), then log out and back in.
* **Keyboard layout:** edit `XKB_DEFAULT_LAYOUT` in `~/.config/labwc/environment`.
  For two layouts use `us,fi`, then switch with `Alt+Shift`.
* **Monitors:** resolution, refresh rate and scale are set in `~/.config/kanshi/config`.
  The default is 3840x2160 at 119.88 Hz with 2.6 scaling. Use `wdisplays` to try out
  settings, then put the ones you want in the kanshi config so they stick.
* **Reload:** `Super+Shift+R` reloads the labwc files. Waybar and mako need a
  logout, or `pkill waybar; waybar &`.

## Audio interface: RME Fireface → AES/EBU → Genelec

For an RME Fireface (UCX II and others) in **class compliant mode** feeding active monitors over
AES/EBU, run once with the interface plugged in:

```sh
setupde-fireface          # set up (AES = output channels 3-4)
setupde-fireface test     # tone on channel 3 (left), then 4 (right)
```

Which playback channels reach the AES output depends on the Fireface's own routing. On this UCX II in
CC mode it's **channels 3-4** (`playback_AUX2` / `playback_AUX3` in qpwgraph), the default; after a
factory reset it's usually 9-10, so use `setupde-fireface setup 9` then. Patching in qpwgraph by hand
works too, but it's lost when PipeWire restarts. `setup` makes it permanent.

**Headphones on the Fireface:** `setupde-fireface headphones 7` adds a second output,
"Headphones (Fireface)", on channels 7-8 (find the right ones with `setupde-fireface test 7`,
`test 5`, ...). Switch between it and the Genelecs with the volume icon.

It switches the card to PipeWire's *Pro Audio* profile, creates a stereo **"Genelec 8330A (AES)"**
output mapped to the AES channels and makes it the default (the panel's volume controls it),
stops the card from suspending (otherwise the monitors lose the digital signal and click when
audio stops), and lets PipeWire follow the music's sample rate (44.1/48/88.2/96 kHz).
`setupde-fireface channels` shows what PipeWire sees, `setupde-fireface remove` undoes it.

**No sound?** Click the volume icon → *Fix sound…*, or run `setupde-fireface fix`. It checks every
step from the apps to the Genelecs:
- the Fireface connected and in Pro Audio mode;
- the Genelec output set up and linked to the Fireface;
- the default output;
- mutes and volume.

It repairs what it can, then plays a test tone. If you don't hear it, it lists what to check on the
Fireface and the Genelecs. The Genelec output also has a high priority: if the default output ever
disappears (for example HDMI audio when the screen switches HDR), sound falls back to the Genelecs.

**Too quiet?** `setupde-fireface levels` lists every volume stage between the apps and the AES output
(panel volume, the internal link, the Fireface output, the card's hardware controls).
`setupde-fireface max` sets them all to full (0 dB), so the panel volume is the only control.
If it's still too quiet after that, the limit is the Fireface front panel (AES output level)
or the monitors' own level.

## Troubleshooting

* **WoW (or another game) shows a stretched corner of the picture, often after Alt+Tab:** in the
  game's settings use Display Mode *Windowed (Fullscreen)*, not *Fullscreen*. Real fullscreen
  makes Wine change the screen resolution, and XWayland only fakes that; switching away and back
  can leave the picture scaled wrong. If it still happens, press Alt+Enter twice in the game.
* **"Lockscreen crashed" picture (Hyprland's own, it mentions hyprlock):** the lock screen app died
  while the screen was locked. Press `Ctrl+Alt+F3`, log in and start a new lock screen with
  `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("swaylock -f")'`, go back with `Ctrl+Alt+F7` and
  type your password. Or unlock right away with
  `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`.
* **No sound:** volume icon → *Fix sound…* (or `setupde-fireface fix`), see the Fireface section.
* **Locked out after being away / a moving picture on screen:** that's PikaOS's own lock screen
  (otter-lock, started by otter-idle after 5 minutes). Move the mouse or press a key, then type your
  password. If nothing reacts, press `Ctrl+Alt+F3`, log in, run `loginctl unlock-sessions`
  (or `pkill otter-lock`), then go back with `Ctrl+Alt+F7`. Running the PikaOS installer again
  switches otter-idle's timers off and makes every lock use swaylock (dark screen with a ring).

* **MediaTek MT7927 Wi‑Fi 7 / Bluetooth** (on many X870 boards, for example MSI and ASUS;
  Bluetooth shows up as USB ID `0489:e110`): Linux only supports this card from
  kernel 7.x. Run `./gaming.sh --kernel` to install `linux-mainline`, which makes Wi‑Fi work.
  Bluetooth also needs a firmware file (`mediatek/mt7927/BT_RAM_CODE_MT6639_*`) that isn't in
  linux-firmware yet, so it won't work until that's released. A USB Bluetooth dongle works
  in the meantime.
  Known issue on kernel 7.2: Wi‑Fi can say *connected* while no traffic gets through (seen
  with an iPhone hotspot). The MT7927 driver is very new, so check again after kernel updates
  (`sudo xbps-install -Su`).

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
