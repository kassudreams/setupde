-- Window, workspace and layer rules.
-- See https://wiki.hypr.land/configuring/basics/window-rules/
--
-- Every workspace starts in FLOATING mode: the first window opens big (fills
-- the screen below the panel), later ones open centred at their normal size
-- and cascade instead of piling up. Double-click a title bar for big/small.
--   Super+M          big / small, like double-clicking the title bar
--   Super+T          tile / float the focused window
--   Super+Shift+T    switch the whole workspace between floating and tiling
--                    (in tiling mode dialogs still float, like normal Hyprland)

local C = require("theme")
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

-- Big / small. A big window is a normal floating window that fills the
-- screen below the panel. (Hyprland's own maximise mode hides the other
-- windows and stops clicks reaching them, so switching windows with the
-- mouse got stuck. A plain big window just comes to the front when clicked.)
local small = {} -- window address -> its place and size before it went big

local function bar_height()
	local ok, hyprbars = pcall(function() return hl.plugin.hyprbars end)
	return (ok and hyprbars) and C.bar_height or 0
end

-- Size of a monitor in desktop units (pixels divided by the scale)
local function monitor_size(m)
	local pw, ph = m.width, m.height
	if m.transform % 2 == 1 then pw, ph = ph, pw end -- rotated 90/270
	return math.floor(pw / m.scale + 0.5), math.floor(ph / m.scale + 0.5)
end

-- Where a big window goes: the monitor minus the panel and the outer gap,
-- minus the border and title bar drawn around the window. Every floating
-- window is kept inside this box, so nothing hides behind the panel.
local function big_box(w)
	local m = w.monitor
	if not m then return nil end
	local mw, mh = monitor_size(m)
	local r, edge, bar = m.reserved, C.gaps_out + C.border, bar_height()
	return {
		x = math.floor(m.x + r.left + edge),
		y = math.floor(m.y + r.top + edge + bar),
		w = math.floor(mw - r.left - r.right - 2 * edge),
		h = math.floor(mh - r.top - r.bottom - 2 * edge - bar),
	}
end

local function near(a, b) return math.abs(a - b) <= 6 end

local function is_big(w, box)
	return near(w.at.x, box.x) and near(w.at.y, box.y) and near(w.size.x, box.w) and near(w.size.y, box.h)
end

-- About as large as a big window (e.g. it was big when the app was closed)
local function nearly_big(w, box)
	return w.size.x >= box.w * 0.9 and w.size.y >= box.h * 0.9
end

local function place(w, x, y, width, height)
	hl.dispatch(hl.dsp.window.resize({ x = math.floor(width), y = math.floor(height), window = w }))
	hl.dispatch(hl.dsp.window.move({ x = math.floor(x), y = math.floor(y), window = w }))
end

local function make_big(w, box)
	if not nearly_big(w, box) then
		small[w.address] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
	end
	place(w, box.x, box.y, box.w, box.h)
end

-- Move (and if needed shrink) a window so all of it, title bar included,
-- is inside the box: below the panel and on the screen
local function fit(box, x, y, width, height)
	width, height = math.min(width, box.w), math.min(height, box.h)
	x = math.max(box.x, math.min(x, box.x + box.w - width))
	y = math.max(box.y, math.min(y, box.y + box.h - height))
	return x, y, width, height
end

local function keep_inside(w, box, x, y)
	local nx, ny, nw, nh = fit(box, x or w.at.x, y or w.at.y, w.size.x, w.size.y)
	if nx ~= w.at.x or ny ~= w.at.y or nw ~= w.size.x or nh ~= w.size.y then
		place(w, nx, ny, nw, nh)
	end
end

local function make_small(w, box)
	local s = small[w.address]
	if not s then -- never been small (it opened big): 60% x 70%, centred
		local width, height = box.w * 0.6, box.h * 0.7
		s = { x = box.x + (box.w - width) / 2, y = box.y + (box.h - height) / 2, w = width, h = height }
	end
	place(w, fit(box, s.x, s.y, s.w, s.h))
end

-- Games (Wine / Proton / Steam) size and place their own window: resizing
-- one makes it show a stretched corner of the picture
local function is_game(w)
	local c = (w.class or ""):lower()
	return c:match("%.exe$") ~= nil or c:match("^steam_app_") ~= nil or c == "gamescope"
end

-- A window that covers the whole monitor. For a game that's its "windowed
-- fullscreen"; any other app (Brave, a terminal, ...) just opens big.
local function covers_monitor(w)
	local m = w.monitor
	if not m then return false end
	local mw, mh = monitor_size(m)
	return w.size.x >= mw - 2 and w.size.y >= mh - 2 and near(w.at.x, m.x) and near(w.at.y, m.y)
end

-- Double-click a title bar, its green button or Super+M
function M.toggle_big(w)
	w = w or hl.get_active_window()
	if not w then return end
	if w.fullscreen ~= 0 then -- Hyprland's maximise (Super+M on a tile) or full screen: undo it
		hl.dispatch(hl.dsp.window.fullscreen({
			mode = w.fullscreen == 1 and "maximized" or "fullscreen", action = "unset", window = w }))
		return
	end
	if not w.floating then -- a tile: Hyprland's maximise, it covers the other tiles
		hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = w }))
		return
	end
	local box = big_box(w)
	if not box then return end
	if is_big(w, box) then make_small(w, box) else make_big(w, box) end
end

hl.on("window.close", function(w)
	if w then small[w.address] = nil end
end)

-- Cascade: a new floating window that lands exactly on another one is
-- nudged down-right until it has its own spot (like labwc).
local STEP = 36
-- Windows that keep their own size and place (no maximise / cascade)
local KEEP_PLACE = { ["setupde-nightlight"] = true }

hl.on("window.open", function(w)
	if not w or not w.floating or not w.workspace then return end
	if w.fullscreen ~= 0 or KEEP_PLACE[w.class or ""] then return end
	if is_game(w) then
		-- a game's "windowed fullscreen": make it real full screen, above the panel
		if covers_monitor(w) then
			hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set", window = w }))
		end
		return
	end
	local others, any_other = {}, false
	for _, o in ipairs(hl.get_workspace_windows(w.workspace)) do
		if o.address ~= w.address then
			any_other = true
			if o.floating then others[#others + 1] = o end
		end
	end

	-- The first window on an empty workspace opens big: it fills the screen
	-- below the panel. Double-click its title bar (or Super+M) to make it small.
	-- An app that was big when it was closed reopens big.
	local box = big_box(w)
	if not box then return end
	if (not any_other and M.float_rules[w.workspace.id]) or nearly_big(w, box) then
		make_big(w, box)
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
	-- an app that opens too tall, or asks for the top of the screen, would
	-- end up partly behind the panel: keep it below
	keep_inside(w, box, x + shift, y + shift)
end)

-- The title-bar plugin loads a few seconds after login (autostart.sh) and the
-- config is reloaded then. Windows that opened before that were sized with
-- no room for a title bar, so their bars ended up behind the panel: fit them
-- again (big ones stay big). Runs after every reload; windows that already
-- fit aren't touched.
hl.on("config.reloaded", function()
	for _, w in ipairs(hl.get_windows()) do
		if w.floating and w.fullscreen == 0 and w.workspace and not w.workspace.special
			and not is_game(w) and not KEEP_PLACE[w.class or ""] then
			local box = big_box(w)
			if box then
				if nearly_big(w, box) then
					make_big(w, box)
				else
					keep_inside(w, box)
				end
			end
		end
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
			-- a maximised tile becomes a big floating window
			local was_max = float and w.fullscreen == 1
			if was_max then
				hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = w }))
			end
			hl.dispatch(hl.dsp.window.float({ action = float and "on" or "off", window = w }))
			local box = was_max and big_box(w)
			if box then make_big(w, box) end
		end
	end
	hl.exec_cmd("notify-send -t 1500 'Workspace " .. ws.id .. "' '" ..
		(float and "Floating windows" or "Tiling windows") .. "'")
end

-- Night light popup: small, top right under the panel, on top
hl.window_rule({
	name  = "nightlight-popup",
	match = { class = "^setupde-nightlight$" },
	float = true,
	move  = "monitor_w-window_w-16 56",
	pin   = true,
	persistent_size = false,
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

return M
