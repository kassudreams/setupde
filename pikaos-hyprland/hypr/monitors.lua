-- Monitor setup. See https://wiki.hypr.land/configuring/core/monitors/
--
-- output = "" applies to every monitor. Use `hyprctl monitors` to see names
-- (e.g. "DP-1") if you want different settings per monitor.
--
-- Scale: Hyprland only accepts scales that divide the resolution into whole
-- pixels. 2.6 doesn't for 3840x2160, so the nearest clean one is used:
--   2.666667 -> 1440x810 desktop (closest to 2.6)
--   2.5      -> 1536x864 desktop (a bit more room)

--
-- HDR is on or off for the whole screen, never switched by apps:
--   game mode (Super+G) turns HDR on, leaving it turns it off again.
-- `setupde-hdr game|on|off` changes the two lines marked below:
--   cm = "srgb"     normal desktop (SDR)
--   cm = "hdr"      HDR all the time (SDR apps are mapped into HDR)
--   cm = "hdredid"  like "hdr", but uses the colour data the TV reports
-- bitdepth = 10 is needed for HDR without banding. If the screen goes black,
-- set it back to 8 (and check "HDMI Ultra HD Deep Colour" on the TV).
-- If HDR looks washed out, raise sdrsaturation (e.g. 1.15) and sdrbrightness.

local M = {
	hdr_in_game_mode = true, -- game mode turns HDR on (setupde-hdr)
}

M.rule = {
	output   = "",
	mode     = "3840x2160@119.88",
	position = "auto",
	scale    = "2.666667",
	bitdepth = 10,
	cm       = "srgb", -- outside game mode, see above (setupde-hdr)
	-- how bright / colourful normal (SDR) content looks while HDR is on
	sdrbrightness = 1.2,
	sdrsaturation = 1.0,
}

hl.monitor(M.rule)

return M
