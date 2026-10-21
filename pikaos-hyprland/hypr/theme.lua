-- Catppuccin Mocha palette and sizes, shared by the other files
local M = {
	base     = "1e1e2e",
	mantle   = "181825",
	surface0 = "313244",
	surface1 = "45475a",
	overlay0 = "6c7086",
	text     = "cdd6f4",
	blue     = "89b4fa",
	mauve    = "cba6f7",
	red      = "f38ba8",
	green    = "a6e3a1",
	yellow   = "f9e2af",
	teal     = "94e2d5",
}

-- Sizes (look.lua, bars.lua, and windows.lua uses them to size big windows)
M.gaps_out   = 14 -- space around windows at the screen edges
M.border     = 2
M.bar_height = 28 -- title bars

-- rgba("89b4fa", "ee") -> "rgba(89b4faee)"
function M.rgba(hex, alpha)
	return "rgba(" .. hex .. (alpha or "ff") .. ")"
end

return M
