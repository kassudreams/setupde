-- Window, workspace and layer rules.
-- See https://wiki.hypr.land/configuring/basics/window-rules/

-- Every window floats and opens centred, like a classic desktop.
-- Super+T tiles the focused window. Delete or comment out this rule to go
-- back to Hyprland's normal tiling.
hl.window_rule({
	name   = "float-by-default",
	match  = { class = ".*" },
	float  = true,
	center = true,
})

-- Ignore apps asking to maximise themselves
hl.window_rule({
	name  = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
	name  = "fix-xwayland-drags",
	match = {
		class      = "^$",
		title      = "^$",
		xwayland   = true,
		float      = true,
		fullscreen = false,
		pin        = false,
	},
	no_focus = true,
})

-- Always show workspaces 1-4 in the panel
for i = 1, 4 do
	hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

-- Frosted glass behind the panel, launcher and notifications
for _, ns in ipairs({ "waybar", "launcher", "notifications" }) do
	hl.layer_rule({
		name  = "blur-" .. ns,
		match = { namespace = "^" .. ns .. "$" },
		blur  = true,
		ignore_alpha = 0.2,
	})
end
