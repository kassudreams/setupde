-- Window, workspace and layer rules.
-- See https://wiki.hypr.land/configuring/basics/window-rules/
--
-- Every window floats (snapping and Arrange are in snap.lua):
--   - the first window on an empty workspace opens big (fills the screen
--     below the panel), later ones open centred at their own size and
--     cascade instead of piling up; every window fits below the panel
--   - games keep the size and place they ask for
--   - minimize: the title bar's yellow button, Super+H, or Super+Down on a
--     window at its own size; click it in the dock to bring it back

local snap = require("snap")
local M = {}

-- Everything floats
hl.window_rule({
	name   = "float-everything",
	match  = { class = ".*" },
	float  = true,
	center = true,
})

-- Dialogs (file pickers, "save changes?", ...) open over their app and are
-- left out of "first window big" and Arrange
hl.window_rule({
	name  = "dialog-tag",
	match = { modal = true },
	tag   = "+dialog",
})

-- A window that covers the whole monitor: a game's "windowed fullscreen"
local function covers_monitor(w)
	local m = w.monitor
	if not m then return false end
	local mw, mh = snap.monitor_size(m)
	return w.size.x >= mw - 2 and w.size.y >= mh - 2 and snap.near(w.at.x, m.x) and snap.near(w.at.y, m.y)
end

-- Cascade: a new window that lands exactly on another one is nudged
-- down-right until it has its own spot (like labwc)
local STEP = 36

hl.on("window.open", function(w)
	if not w or not w.floating or not w.workspace or w.fullscreen ~= 0 then return end
	if snap.is_game(w) then
		-- a game's "windowed fullscreen": make it real full screen, above the panel
		if covers_monitor(w) then
			hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set", window = w }))
		end
		return
	end
	if not snap.normal(w) then
		if not snap.KEEP_PLACE[w.class or ""] then snap.keep_inside(w) end -- dialogs
		return
	end

	local others = {}
	for _, o in ipairs(hl.get_workspace_windows(w.workspace)) do
		if o.address ~= w.address and snap.normal(o) then others[#others + 1] = o end
	end

	-- the first window on an empty workspace opens big
	if #others == 0 then
		snap.snap("big", w)
		return
	end

	local x, y, shift = w.at.x, w.at.y, 0
	for _ = 1, 12 do
		local taken = false
		for _, o in ipairs(others) do
			if math.abs(o.at.x - (x + shift)) < STEP / 2 and math.abs(o.at.y - (y + shift)) < STEP / 2 then
				taken = true
				break
			end
		end
		if not taken then break end
		shift = shift + STEP
	end
	-- an app that opens too big, or asks for the top of the screen, would end
	-- up partly behind the panel: keep it below
	snap.keep_inside(w, x + shift, y + shift)
end)

-- ---------------------------------------------------------------- minimize
-- A minimized window waits on a hidden workspace. Clicking it in the dock
-- (or anything else that activates it) brings it back to the workspace
-- you're on.

local HIDDEN = "special:minimized"

local function hidden(w)
	return w and w.workspace and w.workspace.name == HIDDEN
end

function M.minimize(w)
	w = w or hl.get_active_window()
	if not w or hidden(w) then return end
	hl.dispatch(hl.dsp.window.move({ workspace = HIDDEN, follow = false, window = w }))
end

local function restore(w)
	local ws = hl.get_active_workspace()
	if not ws or not hidden(w) then return end
	hl.dispatch(hl.dsp.window.move({ workspace = ws.id, follow = true, window = w }))
	hl.dispatch(hl.dsp.focus({ window = w }))
	local sp = hl.get_active_special_workspace()
	if sp and sp.name == HIDDEN then
		hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))
	end
end

-- the dock's right-click (minimize / raise) and apps asking to minimize
hl.on("window.minimize", function(w, on)
	if on then M.minimize(w) else restore(w) end
end)
-- the dock's left-click activates the window
hl.on("window.active", function(w)
	if hidden(w) then restore(w) end
end)

-- ---------------------------------------------------------------- rules

-- Night light popup: small, top right under the panel, on top
hl.window_rule({
	name  = "nightlight-popup",
	match = { class = "^setupde-nightlight$" },
	float = true,
	move  = "monitor_w-window_w-16 56",
	pin   = true,
})

-- Ignore apps asking to maximise themselves (big is a snap zone here)
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
