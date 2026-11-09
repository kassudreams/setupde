-- Snapping. Every window floats; a "tile" is a floating window snapped to a
-- zone of the screen below the panel, so clicking any window always brings it
-- to the front and nothing gets stuck behind anything.
--
--   Super+Left/Right   left / right half; again: 1/2 -> 1/3 -> 2/3
--   Super+Up           big; a half goes to its top quarter
--   Super+Down         back to its own size; a half goes to its bottom quarter;
--                      a window at its own size is minimized
--   drag to an edge    left/right edge: half, top edge: big, corner: quarter
--   (pause ~0.3 s)     (Hyprland can't tell when the mouse button is let go,
--                      so it snaps once the window rests at the edge)
--   Super+T            Arrange: tile every window on the workspace; again: undo
--   Super+M / double-click the title bar: big <-> own size
--
-- A window's own ("free") size and place is remembered when it snaps, and
-- comes back when it's unsnapped or dragged away from its zone.

local C = require("theme")
local M = {}

-- ---------------------------------------------------------------- geometry

local function bar_height()
	local ok, hyprbars = pcall(function() return hl.plugin.hyprbars end)
	return (ok and hyprbars) and C.bar_height or 0
end

-- Size of a monitor in desktop units (pixels divided by the scale)
function M.monitor_size(m)
	local pw, ph = m.width, m.height
	if m.transform % 2 == 1 then pw, ph = ph, pw end -- rotated 90/270
	return math.floor(pw / m.scale + 0.5), math.floor(ph / m.scale + 0.5)
end

function M.near(a, b) return math.abs(a - b) <= 6 end
local near = M.near

-- The area windows live in: the monitor minus the panel and the outer gap
local function area(w)
	local m = w.monitor
	if not m then return nil end
	local mw, mh = M.monitor_size(m)
	local r, g = m.reserved, C.gaps_out
	return { x = m.x + r.left + g, y = m.y + r.top + g,
	         w = mw - r.left - r.right - 2 * g, h = mh - r.top - r.bottom - 2 * g }
end

-- An outer rectangle -> the window's own box (border and title bar are
-- drawn around the window, outside its box)
local function client(o)
	local b, bar = C.border, bar_height()
	return { x = math.floor(o.x + b), y = math.floor(o.y + b + bar),
	         w = math.floor(o.w - 2 * b), h = math.floor(o.h - 2 * b - bar) }
end

-- The box all of a window has to stay in (title bar included)
function M.box(w)
	local a = area(w)
	return a and client(a)
end

-- Move (and if needed shrink) a geometry so it fits inside the box
function M.fit(box, x, y, width, height)
	width, height = math.min(width, box.w), math.min(height, box.h)
	x = math.max(box.x, math.min(x, box.x + box.w - width))
	y = math.max(box.y, math.min(y, box.y + box.h - height))
	return x, y, width, height
end

-- ---------------------------------------------------------------- state
-- st[address] = { free = {x,y,w,h} or nil, zone = {...} or nil,
--                  prev = the zone it had before Arrange, or nil }
-- Kept in a small file: Hyprland starts the config from scratch on every
-- reload, and snapped windows should stay snapped across that.

local STATE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/setupde-snap.state"
local st, expected = {}, {}

local function encode_zone(z)
	if not z then return "-" end
	return table.concat({ z.name, z.f or 1, z.c or 0, z.r or 0, z.cols or 0, z.rows or 0, z.arranged and 1 or 0 }, ":")
end

local function decode_zone(s)
	if s == "-" then return nil end
	local p = {}
	for v in s:gmatch("[^:]+") do p[#p + 1] = v end
	return { name = p[1], f = tonumber(p[2]) or 1, c = tonumber(p[3]), r = tonumber(p[4]),
	         cols = tonumber(p[5]), rows = tonumber(p[6]), arranged = p[7] == "1" }
end

local function save()
	local f = io.open(STATE, "w")
	if not f then return end
	for addr, s in pairs(st) do
		if s.free or s.zone then
			local fr = s.free and string.format("%d,%d,%d,%d", s.free.x, s.free.y, s.free.w, s.free.h) or "-"
			f:write(addr, " ", fr, " ", encode_zone(s.zone), " ", encode_zone(s.prev), "\n")
		end
	end
	f:close()
end

local function load()
	local f = io.open(STATE, "r")
	if not f then return end
	for line in f:lines() do
		local addr, fr, z, prev = line:match("^(%S+) (%S+) (%S+) (%S+)$")
		if addr then
			local free
			if fr ~= "-" then
				local x, y, w, h = fr:match("^(-?%d+),(-?%d+),(%d+),(%d+)$")
				if x then free = { x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h) } end
			end
			st[addr] = { free = free, zone = decode_zone(z), prev = decode_zone(prev) }
		end
	end
	f:close()
end

local function state(w)
	local s = st[w.address]
	if not s then s = {}; st[w.address] = s end
	return s
end

function M.zone(w)
	local s = st[w.address]
	return s and s.zone
end

-- ---------------------------------------------------------------- placing

local function place(w, x, y, width, height)
	x, y, width, height = math.floor(x), math.floor(y), math.floor(width), math.floor(height)
	expected[w.address] = { x = x, y = y, w = width, h = height }
	hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = w }))
	hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = w }))
end
M.place = place

-- Keep a window (or the given position for it) fully below the panel
function M.keep_inside(w, x, y)
	local box = M.box(w)
	if not box then return end
	local nx, ny, nw, nh = M.fit(box, x or w.at.x, y or w.at.y, w.size.x, w.size.y)
	if nx ~= w.at.x or ny ~= w.at.y or nw ~= w.size.x or nh ~= w.size.y then
		place(w, nx, ny, nw, nh)
	end
end

-- ---------------------------------------------------------------- zones

local WIDTHS = { 1 / 2, 1 / 3, 2 / 3 } -- half widths, cycled by Super+Left/Right

-- Outer rectangle of a zone inside the area
local function zone_rect(a, z)
	local G = 2 * C.gaps_in -- space between two snapped windows
	local function col(side, f)
		local wd = math.floor((a.w - G) * f + 0.5)
		if side == "left" then return a.x, wd end
		return a.x + a.w - wd, wd
	end
	local function row(part)
		local ht = math.floor((a.h - G) / 2 + 0.5)
		if part == "top" then return a.y, ht end
		return a.y + a.h - ht, a.h - G - ht
	end
	local n = z.name
	if n == "big" then return { x = a.x, y = a.y, w = a.w, h = a.h } end
	if n == "left" or n == "right" then
		local x, wd = col(n, WIDTHS[z.f or 1])
		return { x = x, y = a.y, w = wd, h = a.h }
	end
	if n == "tl" or n == "tr" or n == "bl" or n == "br" then
		local x, wd = col(n:sub(2, 2) == "l" and "left" or "right", WIDTHS[z.f or 1])
		local y, ht = row(n:sub(1, 1) == "t" and "top" or "bottom")
		return { x = x, y = y, w = wd, h = ht }
	end
	if n == "grid" then
		local cw = (a.w - G * (z.cols - 1)) / z.cols
		local ch = (a.h - G * (z.rows - 1)) / z.rows
		return { x = a.x + z.c * (cw + G), y = a.y + z.r * (ch + G), w = cw, h = ch }
	end
end

-- Snap a window to a zone: "big", "left", "right", "tl", "tr", "bl", "br",
-- or a zone table. Its own size and place is remembered first.
function M.snap(z, w)
	w = w or hl.get_active_window()
	if not w or w.fullscreen ~= 0 then return end
	if type(z) == "string" then z = { name = z, f = 1 } end
	local a = area(w)
	if not a then return end
	local s = state(w)
	if not s.zone then
		s.free = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
	end
	if not z.arranged then s.prev = nil end
	if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "on", window = w })) end
	local r = client(zone_rect(a, z))
	place(w, r.x, r.y, r.w, r.h)
	s.zone = z
	save()
end

-- Back to the window's own size and place
function M.free(w)
	w = w or hl.get_active_window()
	if not w then return end
	local box = M.box(w)
	if not box then return end
	local s = state(w)
	local fr = s.free
	if not fr then -- it never had its own size (it opened big): 60% x 70%, centred
		local width, height = box.w * 0.6, box.h * 0.7
		fr = { x = box.x + (box.w - width) / 2, y = box.y + (box.h - height) / 2, w = width, h = height }
	end
	place(w, M.fit(box, fr.x, fr.y, fr.w, fr.h))
	s.zone, s.prev = nil, nil
	save()
end

-- Super+M, the title bar's double-click and its green button
function M.toggle_big(w)
	w = w or hl.get_active_window()
	if not w then return end
	if w.fullscreen ~= 0 then -- full screen (Super+F): just leave it
		hl.dispatch(hl.dsp.window.fullscreen({
			mode = w.fullscreen == 1 and "maximized" or "fullscreen", action = "unset", window = w }))
		return
	end
	local z = M.zone(w)
	if z and z.name == "big" then M.free(w) else M.snap("big", w) end
end

-- Super+arrows
function M.key(dir)
	local w = hl.get_active_window()
	if not w or w.fullscreen ~= 0 then return end
	local z = M.zone(w)
	local n = z and z.name or "free"
	if n == "grid" then n = "free" end
	local f = z and z.f or 1
	local side = (n == "left" or n == "tl" or n == "bl") and "l" or ((n == "right" or n == "tr" or n == "br") and "r")

	if dir == "left" or dir == "right" then
		local d = dir == "left" and "l" or "r"
		if n == "free" or n == "big" then
			M.snap({ name = dir, f = 1 }, w)
		elseif n == "left" or n == "right" then
			if side == d then M.snap({ name = n, f = f % #WIDTHS + 1 }, w) else M.free(w) end
		else -- a quarter: across to the other side, same row
			if side ~= d then M.snap({ name = n:sub(1, 1) .. d, f = f }, w) end
		end
	elseif dir == "up" then
		if n == "free" then M.snap("big", w)
		elseif n == "left" or n == "right" then M.snap({ name = "t" .. side, f = f }, w)
		elseif n == "bl" or n == "br" then M.snap({ name = side == "l" and "left" or "right", f = f }, w)
		end
	elseif dir == "down" then
		if n == "big" then M.free(w)
		elseif n == "left" or n == "right" then M.snap({ name = "b" .. side, f = f }, w)
		elseif n == "tl" or n == "tr" then M.snap({ name = side == "l" and "left" or "right", f = f }, w)
		elseif n == "free" then require("windows").minimize(w)
		end
	end
end

-- ---------------------------------------------------------------- Arrange

local function has_tag(w, tag)
	for _, t in ipairs(w.tags or {}) do
		if t == tag or t == tag .. "*" then return true end
	end
	return false
end

-- Games (Wine / Proton / Steam) size and place their own window: resizing
-- one makes it show a stretched corner of the picture
function M.is_game(w)
	local c = (w.class or ""):lower()
	return c:match("%.exe$") ~= nil or c:match("^steam_app_") ~= nil or c == "gamescope"
end

-- Windows that keep their own size and place (no snapping, no cascade)
M.KEEP_PLACE = { ["setupde-nightlight"] = true }

-- A normal window: snapping, Arrange and the opening rules apply to it
function M.normal(w)
	return w and w.floating and w.fullscreen == 0 and w.workspace and not w.workspace.special
		and not w.pinned and not M.is_game(w) and not M.KEEP_PLACE[w.class or ""]
		and not has_tag(w, "dialog")
end

local function layout(n)
	if n == 1 then return { { name = "big" } } end
	if n == 2 then return { { name = "left" }, { name = "right" } } end
	if n == 3 then return { { name = "left" }, { name = "tr" }, { name = "br" } } end
	if n == 4 then return { { name = "tl" }, { name = "tr" }, { name = "bl" }, { name = "br" } } end
	local cols = math.ceil(math.sqrt(n))
	local rows = math.ceil(n / cols)
	local zones = {}
	for i = 0, n - 1 do
		zones[#zones + 1] = { name = "grid", c = i % cols, r = i // cols, cols = cols, rows = rows }
	end
	return zones
end

-- Super+T: tile every window on the workspace; again: put them back
function M.arrange()
	local ws = hl.get_active_workspace()
	if not ws or ws.special then return end
	local wins = {}
	local arranged = false
	for _, w in ipairs(hl.get_workspace_windows(ws)) do
		if M.normal(w) then
			wins[#wins + 1] = w
			local z = M.zone(w)
			if z and z.arranged then arranged = true end
		end
	end
	if arranged then -- undo: each window back to what it had before
		for _, w in ipairs(wins) do
			local z = M.zone(w)
			if z and z.arranged then
				local prev = st[w.address].prev
				st[w.address].prev = nil
				if prev then M.snap(prev, w) else M.free(w) end
			end
		end
		return
	end
	if #wins == 0 then return end
	table.sort(wins, function(a, b)
		if a.at.x ~= b.at.x then return a.at.x < b.at.x end
		return a.at.y < b.at.y
	end)
	for i, z in ipairs(layout(#wins)) do
		z.f, z.arranged = 1, true
		state(wins[i]).prev = M.zone(wins[i])
		M.snap(z, wins[i])
	end
end

-- ---------------------------------------------------------------- dragging
-- Hyprland has no "drop" event, so a timer watches the active window. A
-- window that moved and then rests with the cursor at a screen edge snaps
-- there. A snapped window that comes to rest away from the edges gets its
-- own size back, with the spot you grabbed it still under the cursor.

local EDGE, CORNER, REST_TICKS = 3, 60, 3

-- Which zone the cursor points at, if it's at a screen edge
local function edge_zone(w, cur)
	local m = w.monitor
	if not m then return nil end
	local mw, mh = M.monitor_size(m)
	local x, y = cur.x - m.x, cur.y - m.y
	local left, right = x <= EDGE, x >= mw - 1 - EDGE
	local top, bottom = y <= EDGE, y >= mh - 1 - EDGE
	local near_top, near_bottom = y <= m.reserved.top + CORNER, y >= mh - CORNER
	local near_left, near_right = x <= CORNER, x >= mw - CORNER
	if left then return near_top and "tl" or (near_bottom and "bl" or "left") end
	if right then return near_top and "tr" or (near_bottom and "br" or "right") end
	if top then return near_left and "tl" or (near_right and "tr" or "big") end
	if bottom then return near_left and "bl" or (near_right and "br" or nil) end
	return nil
end

local watch = { addr = nil, still = 0, moved = false }

local function ours(w)
	local e = expected[w.address]
	return e and near(e.x, w.at.x) and near(e.y, w.at.y) and near(e.w, w.size.x) and near(e.h, w.size.y)
end

function M.tick()
	local w = hl.get_active_window()
	if not M.normal(w) then
		watch.addr = nil
		return
	end
	local x, y, sw, sh = w.at.x, w.at.y, w.size.x, w.size.y
	if w.address ~= watch.addr then
		watch = { addr = w.address, x = x, y = y, w = sw, h = sh, still = 0, moved = false }
		return
	end
	if sw ~= watch.w or sh ~= watch.h then
		-- resized by hand: it's no longer exactly in its zone, so it's free now
		if not ours(w) then
			local s = st[w.address]
			if s and s.zone then s.zone, s.free = nil, nil; save() end
		end
		watch.moved = false
	elseif x ~= watch.x or y ~= watch.y then
		if not ours(w) then watch.moved, watch.still = true, 0 end
	elseif watch.moved then
		watch.still = watch.still + 1
		if watch.still >= REST_TICKS then
			watch.moved = false
			local cur = hl.get_cursor_pos()
			local z = cur and edge_zone(w, cur)
			if z then
				M.snap(z, w)
			elseif M.zone(w) then
				-- dragged off its zone: own size again, grabbed spot under the cursor
				local s = st[w.address]
				local fr = s.free
				local box = M.box(w)
				if fr and cur and box then
					local rel = sw > 0 and (cur.x - x) / sw or 0.5
					place(w, M.fit(box, cur.x - rel * fr.w, y, fr.w, fr.h))
				end
				s.zone = nil
				save()
			end
		end
	end
	watch.x, watch.y, watch.w, watch.h = w.at.x, w.at.y, w.size.x, w.size.y
end

-- ---------------------------------------------------------------- events

-- The config was reloaded (a file saved, HDR switched, or the title bars
-- loaded a few seconds after login): snapped windows go back into their
-- zone (it changes when the title bars appear), the rest stay below the panel
local function refit()
	for _, w in ipairs(hl.get_windows()) do
		if M.normal(w) then
			local z = M.zone(w)
			if z then
				local a = area(w)
				if a then
					local r = client(zone_rect(a, z))
					if not (near(r.x, w.at.x) and near(r.y, w.at.y) and near(r.w, w.size.x) and near(r.h, w.size.y)) then
						place(w, r.x, r.y, r.w, r.h)
					end
				end
			else
				M.keep_inside(w)
			end
		end
	end
end

load()
hl.on("config.reloaded", refit)
hl.on("window.close", function(w)
	if w and st[w.address] then
		st[w.address], expected[w.address] = nil, nil
		save()
	end
end)
-- a new session starts without old windows' state
hl.on("hyprland.start", function()
	st = {}
	os.remove(STATE)
end)
hl.timer(M.tick, { timeout = 100, type = "repeat" })

return M
