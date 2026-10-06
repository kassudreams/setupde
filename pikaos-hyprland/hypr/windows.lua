-- Window, workspace and layer rules.
-- See https://wiki.hypr.land/configuring/basics/window-rules/
--
-- Every workspace starts in FLOATING mode: the first window opens big (fills
-- the screen below the panel), later ones open centred at their normal size
-- and cascade instead of piling up. Double-click a title bar for big/small.
--   Super+T          tile / float the focused window
--   Super+Shift+T    switch the whole workspace between floating and tiling
--                    (in tiling mode dialogs still float, like normal Hyprland)

local M = {}

-- One "float everything" rule per workspace, so each workspace can be
-- switched to tiling on its own by turning its rule off.
M.float_rules = {}
for i = 1, 10 do
	M.float_rules[i] = hl.window_rule({
		name   = "float-ws-" .. i,
		match  = { class = ".*", workspace = tostring(i) },
		float  = true,
		center = true,
		persistent_size = true, -- apps reopen at the size you last gave them
	})
end

-- Cascade: a new floating window that lands exactly on another one is
-- nudged down-right until it has its own spot (like labwc).
local STEP = 36
hl.on("window.open", function(w)
	if not w or not w.floating or not w.workspace then return end
	local others, any_other = {}, false
	for _, o in ipairs(hl.get_workspace_windows(w.workspace)) do
		if o.address ~= w.address then
			any_other = true
			if o.floating then others[#others + 1] = o end
		end
	end

	-- The first window on an empty workspace opens big: it fills the screen
	-- below the panel. Double-click its title bar (or Super+M) to make it small.
	if not any_other and M.float_rules[w.workspace.id] then
		hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = w }))
		return
	end
	local x, y, shift = w.at.x, w.at.y, 0
	for _ = 1, 12 do
		local taken = false
		for _, o in ipairs(others) do
			local p = o.at
			if math.abs(p.x - (x + shift)) < STEP / 2 and math.abs(p.y - (y + shift)) < STEP / 2 then
				taken = true
				break
			end
		end
		if not taken then break end
		shift = shift + STEP
	end
	if shift > 0 then
		hl.dispatch(hl.dsp.window.move({ x = shift, y = shift, relative = true, window = w }))
	end
end)

-- Super+Shift+T: switch the active workspace between floating and tiling
function M.toggle_workspace_mode()
	local ws = hl.get_active_workspace()
	if not ws or ws.special then return end
	local rule = M.float_rules[ws.id]
	if not rule then return end

	local float = not rule:is_enabled()
	rule:set_enabled(float)
	for _, w in ipairs(hl.get_workspace_windows(ws)) do
		if w.floating ~= float then
			hl.dispatch(hl.dsp.window.float({ action = float and "on" or "off", window = w }))
		end
	end
	hl.exec_cmd("notify-send -t 1500 'Workspace " .. ws.id .. "' '" ..
		(float and "Floating windows" or "Tiling windows") .. "'")
end

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

return M
