-- Game mode: Super+G, or `setupde-gamemode on` / `off` from a script (for
-- example Lutris' pre-launch and post-exit scripts). While it's on:
--   - no blur, shadows or animations, and inactive windows aren't
--     see-through, so the game gets the GPU time
--   - VRR (G-Sync / FreeSync) for fullscreen windows, if the monitor has it
--   - notifications are hidden and the night light is paused
-- A gamepad icon shows in the panel; click it or press Super+G to go back.

local M = {}

local FLAG = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/setupde-gamemode"
local WAYBAR_SIGNAL = 10 -- "signal": 10 in the panel's custom/gamemode

function M.is_on()
	local f = io.open(FLAG, "r")
	if f then f:close() end
	return f ~= nil
end

local function game_look()
	hl.config({
		animations = { enabled = false },
		decoration = {
			blur   = { enabled = false },
			shadow = { enabled = false },
			inactive_opacity = 1.0,
		},
		misc = { vrr = 2 }, -- 2 = VRR for fullscreen windows
	})
end

function M.set(on)
	if on == M.is_on() then return end
	if on then
		local f = io.open(FLAG, "w")
		if f then f:close() end
		game_look()
		hl.exec_cmd("makoctl mode -a do-not-disturb; hyprctl hyprsunset identity")
	else
		os.remove(FLAG)
		package.loaded["look"] = nil
		require("look") -- back to the normal look, as look.lua has it
		hl.exec_cmd("makoctl mode -r do-not-disturb; setupde-nightlight resume")
	end
	hl.exec_cmd("pkill -RTMIN+" .. WAYBAR_SIGNAL .. " -x waybar")
end

function M.toggle()
	M.set(not M.is_on())
end

-- The config was reloaded (a file was saved, or HDR switched) during game
-- mode: look.lua just put the normal look back, so keep game mode's
if M.is_on() then game_look() end

-- A new session always starts in normal mode
hl.on("hyprland.start", function()
	if M.is_on() then M.set(false) end
end)

return M
