-- Keyboard shortcuts (same as the setupde labwc desktop where possible).
-- See https://wiki.hypr.land/configuring/basics/binds/

local mod = "SUPER"
local function exec(cmd) return hl.dsp.exec_cmd(cmd) end

-- First browser that is installed
local function first_installed(names)
	for _, name in ipairs(names) do
		for _, dir in ipairs({ "/usr/bin/", "/usr/local/bin/" }) do
			local f = io.open(dir .. name, "r")
			if f then f:close(); return name end
		end
	end
	return names[1]
end
local browser = first_installed({ "firefox", "chromium", "google-chrome-stable", "brave-browser" })

-- Apps
hl.bind(mod .. " + Return",       exec("foot"))
hl.bind(mod .. " + space",        exec("fuzzel"))
hl.bind(mod .. " + R",            exec("fuzzel"))
hl.bind(mod .. " + SHIFT + space", exec("setupde-dock pin"))   -- pin an app to the dock
hl.bind(mod .. " + E",            exec("thunar"))
hl.bind(mod .. " + B",            exec(browser))
hl.bind(mod .. " + V",            exec("setupde-clipboard"))
hl.bind(mod .. " + L",            exec("swaylock -f"))
hl.bind(mod .. " + Escape",       exec("setupde-powermenu"))
hl.bind("CTRL + ALT + Delete",    exec("setupde-powermenu"))
hl.bind(mod .. " + N",            exec("makoctl dismiss --all"))

-- Screenshots (saved to ~/Pictures/Screenshots and copied to the clipboard)
hl.bind("Print",                  exec("setupde-screenshot area"))
hl.bind("SHIFT + Print",          exec("setupde-screenshot full"))
hl.bind("CTRL + Print",           exec("setupde-screenshot edit"))

-- Windows
hl.bind(mod .. " + Q",            hl.dsp.window.close())
hl.bind("ALT + F4",               hl.dsp.window.close())
hl.bind(mod .. " + F",            hl.dsp.window.fullscreen())
hl.bind(mod .. " + M",            hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + T",            hl.dsp.window.float({ action = "toggle" })) -- tile / float this window
hl.bind(mod .. " + SHIFT + T",    require("windows").toggle_workspace_mode)   -- whole workspace
hl.bind(mod .. " + C",            hl.dsp.window.center())
hl.bind(mod .. " + P",            hl.dsp.window.pin()) -- keep on top on every workspace

-- Alt+Tab: next window, raised above the others
local function cycle(next)
	return function()
		hl.dispatch(hl.dsp.window.cycle_next({ next = next }))
		hl.dispatch(hl.dsp.window.bring_to_top())
	end
end
hl.bind("ALT + Tab",              cycle(true))
hl.bind("ALT + SHIFT + Tab",      cycle(false))
hl.bind(mod .. " + Tab",          cycle(true))

-- Focus / move with the arrow keys
for _, dir in ipairs({ "left", "right", "up", "down" }) do
	hl.bind(mod .. " + " .. dir,          hl.dsp.focus({ direction = dir }))
	hl.bind(mod .. " + SHIFT + " .. dir,  hl.dsp.window.move({ direction = dir }))
end

-- Workspaces
for i = 1, 4 do
	hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }))
end
hl.bind(mod .. " + CTRL + left",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",     hl.dsp.focus({ workspace = "e-1" }))

-- Scratchpad: a hidden workspace you can pop up over everything
hl.bind(mod .. " + S",            hl.dsp.workspace.toggle_special("scratch"))
hl.bind(mod .. " + SHIFT + S",    hl.dsp.window.move({ workspace = "special:scratch" }))

-- Mouse: Super+left drag moves, Super+right drag resizes
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Session
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

-- Media keys
hl.bind("XF86AudioRaiseVolume",  exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",      exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   exec("brightnessctl set 5%+"),                          { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", exec("brightnessctl set 5%-"),                          { locked = true, repeating = true })
hl.bind("XF86AudioNext",         exec("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",         exec("playerctl previous"),   { locked = true })
hl.bind("XF86AudioPlay",         exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",        exec("playerctl play-pause"), { locked = true })
