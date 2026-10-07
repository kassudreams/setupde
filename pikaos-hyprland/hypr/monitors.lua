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
-- HDR (switch with `setupde-hdr auto|on|off`, which edits the cm line):
--   cm = "srgb"     normal desktop; games/videos that output HDR switch the
--                   screen to HDR by themselves while fullscreen (auto mode)
--   cm = "hdr"      HDR all the time (SDR apps are mapped into HDR)
--   cm = "hdredid"  like "hdr", but uses the colour data the TV reports
-- bitdepth = 10 is needed for HDR without banding. If the screen goes black,
-- set it back to 8 (and check "HDMI Ultra HD Deep Colour" on the TV).

hl.monitor({
	output   = "",
	mode     = "3840x2160@119.88",
	position = "auto",
	scale    = "2.666667",
	bitdepth = 10,
	cm       = "srgb", -- HDR mode, see above
	-- how bright / colourful normal (SDR) content looks while HDR is on
	sdrbrightness = 1.2,
	sdrsaturation = 1.0,
})
