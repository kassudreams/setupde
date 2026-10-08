-- Environment variables. See https://wiki.hypr.land/configuring/core/environment-variables/

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

-- Dark mode everywhere: GTK3 apps (Thunar, Lutris, ...) and libadwaita apps
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("ADW_DEBUG_COLOR_SCHEME", "prefer-dark")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("TERMINAL", "foot")

-- X11 apps run at native resolution (see xwayland in look.lua), so games get
-- the full 3840x2160. Make the Steam client itself readable:
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "2")

-- NVIDIA: detected at every start, so this also works if the card numbering
-- changes. With two GPUs (CPU graphics + NVIDIA card), only use the NVIDIA
-- card, where the monitor is plugged in.
local function read_line(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local line = f:read("*l")
	f:close()
	return line
end

local gpus, nvidia = 0, nil
for i = 0, 15 do
	local vendor = read_line("/sys/class/drm/card" .. i .. "/device/vendor")
	if vendor then
		gpus = gpus + 1
		if vendor == "0x10de" and not nvidia then
			nvidia = "/dev/dri/card" .. i
		end
	end
end

if nvidia then
	hl.env("LIBVA_DRIVER_NAME", "nvidia")
	hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
	hl.env("NVD_BACKEND", "direct")
	if gpus > 1 then
		hl.env("AQ_DRM_DEVICES", nvidia)
	end
end

-- GNU Guix (installed next to PikaOS): make its programs, app launchers,
-- language data and cursor themes visible to the desktop. Harmless when
-- Guix isn't installed. Guix's own `guix` (after `guix pull`) comes first;
-- other Guix programs come after the system ones, so they don't replace them.
local home = os.getenv("HOME") or ""
local guix = home .. "/.guix-profile"

local function with(var, default, before, after)
	local cur = os.getenv(var)
	if cur == nil or cur == "" then cur = default end
	local padded = ":" .. cur .. ":"
	local parts = {}
	for _, p in ipairs(before) do
		if not padded:find(":" .. p .. ":", 1, true) then parts[#parts + 1] = p end
	end
	parts[#parts + 1] = cur
	for _, p in ipairs(after) do
		if not padded:find(":" .. p .. ":", 1, true) then parts[#parts + 1] = p end
	end
	hl.env(var, table.concat(parts, ":"))
end

with("PATH", "/usr/local/bin:/usr/bin:/bin",
	{ home .. "/.config/guix/current/bin" }, { guix .. "/bin" })
with("XDG_DATA_DIRS", "/usr/local/share:/usr/share", {}, { guix .. "/share" })
with("XCURSOR_PATH", home .. "/.local/share/icons:" .. home .. "/.icons:/usr/share/icons:/usr/share/pixmaps",
	{}, { guix .. "/share/icons" })
hl.env("GUIX_LOCPATH", guix .. "/lib/locale")
