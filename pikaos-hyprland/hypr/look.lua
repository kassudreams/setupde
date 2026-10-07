-- Look and feel: Catppuccin Mocha, big soft shadows, blur, springy animations.
-- See https://wiki.hypr.land/configuring/basics/variables/

local C = require("theme")
local rgba = C.rgba

hl.config({
	general = {
		gaps_in  = 6,
		gaps_out = 14,
		border_size = 2,
		col = {
			active_border   = { colors = { rgba(C.blue, "ee"), rgba(C.mauve, "ee") }, angle = 45 },
			inactive_border = rgba(C.surface0, "cc"),
		},
		resize_on_border = true,
		layout = "dwindle", -- used for windows you tile with Super+T
		snap = {
			enabled    = true, -- floating windows snap to edges and each other
			window_gap = 12,
		},
	},

	decoration = {
		rounding       = 12,
		rounding_power = 2,
		active_opacity   = 1.0,
		inactive_opacity = 0.95,

		shadow = {
			enabled      = true,
			range        = 30,
			render_power = 3,
			offset       = "0 8",
			color        = rgba("000000", "99"),
		},

		blur = {
			enabled  = true,
			size     = 6,
			passes   = 3,
			noise    = 0.02,
			vibrancy = 0.17,
		},
	},

	animations = {
		enabled = true,
	},

	dwindle = {
		preserve_split = true,
	},

	misc = {
		force_default_wallpaper  = 0,
		disable_hyprland_logo    = true,
		disable_splash_rendering = true,
		background_color         = rgba(C.base),
		focus_on_activate        = true,
		-- PikaOS's session sets XDG_CURRENT_DESKTOP=pika-hyprland on purpose
		-- (it picks PikaOS's portal settings), so don't warn about it
		disable_xdg_env_checks   = true,
	},

	-- X11 apps (Wine/Proton games, Battle.net, Steam) render at native pixels
	-- instead of being upscaled. Games see the full 3840x2160 while the
	-- desktop keeps its scale, so Alt+Tab looks right in both.
	xwayland = {
		force_zero_scaling = true,
	},

	-- HDR: switch the screen to HDR when a fullscreen game/video outputs HDR
	-- (1 = on, 0 = off; `setupde-hdr` changes this)
	render = {
		cm_auto_hdr = 1,
	},
})

-- Animations: windows pop in on a soft spring and drift out
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1},   {0.32, 1} } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},      {1, 1}    } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5},  {0.75, 1} } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0},   {0.1, 1}  } })
hl.curve("floaty",       { type = "spring", mass = 1, stiffness = 180, dampening = 20 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "floaty" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "floaty",       style = "popin 85%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 85%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2.5,  bezier = "easeOutQuint", style = "slidefade 15%" })
