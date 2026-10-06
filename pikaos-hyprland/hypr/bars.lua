-- Title bars on every window (hyprbars plugin, installed by install.sh).
--   drag the bar         move the window
--   double-click it      big (fills the screen below the panel) <-> small
--   buttons              close / big-small / hide (Super+S brings hidden back)
-- Does nothing until the plugin is loaded (autostart.sh loads it).

local ok, hyprbars = pcall(function() return hl.plugin.hyprbars end)
if not ok or not hyprbars then return end

local C = require("theme")
local rgba = C.rgba

local TOGGLE_BIG = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })']]

hl.config({
	plugin = {
		hyprbars = {
			bar_height       = 28,
			bar_color        = rgba(C.mantle),
			["col.text"]     = rgba(C.text),
			inactive_button_color = rgba(C.surface1),
			bar_text_font    = "Inter",
			bar_text_size    = 10,
			bar_text_weight  = "semibold",
			bar_text_align   = "center",
			bar_buttons_alignment = "right",
			bar_padding      = 10,
			bar_button_padding = 7,
			bar_part_of_window = true,
			bar_precedence_over_border = true,
			bar_blur         = true,
			on_double_click  = TOGGLE_BIG,
		},
	},
})

-- Buttons, right to left: close, big/small, hide
hyprbars.add_button({
	bg_color = rgba(C.red), fg_color = rgba(C.base), size = 14, icon = "",
	action = [[hyprctl dispatch 'hl.dsp.window.close()']],
})
hyprbars.add_button({
	bg_color = rgba(C.green), fg_color = rgba(C.base), size = 14, icon = "",
	action = TOGGLE_BIG,
})
hyprbars.add_button({
	bg_color = rgba(C.yellow), fg_color = rgba(C.base), size = 14, icon = "",
	action = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:scratch", follow = false })']],
})
