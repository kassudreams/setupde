-- Monitor setup. See https://wiki.hypr.land/configuring/core/monitors/
--
-- output = "" applies to every monitor. Use `hyprctl monitors` to see names
-- (e.g. "DP-1") if you want different settings per monitor.
--
-- Scale: Hyprland only accepts scales that divide the resolution into whole
-- pixels. 2.6 doesn't for 3840x2160, so the nearest clean one is used:
--   2.666667 -> 1440x810 desktop (closest to 2.6)
--   2.5      -> 1536x864 desktop (a bit more room)

hl.monitor({
	output   = "",
	mode     = "3840x2160@119.88",
	position = "auto",
	scale    = "2.666667",
})
