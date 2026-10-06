-- Keyboard, mouse, touchpad. See https://wiki.hypr.land/configuring/basics/variables/#input

hl.config({
	input = {
		kb_layout  = "@KB_LAYOUT@",
		-- For two layouts use e.g. kb_layout = "fi,us" and
		-- kb_options = "grp:alt_shift_toggle" (Alt+Shift switches)
		kb_options = "",
		numlock_by_default = true,
		repeat_rate  = 30,
		repeat_delay = 300,

		-- 2 = click to focus (like a normal floating desktop); the pointer
		-- still scrolls whatever window it's over.
		follow_mouse = 2,
		sensitivity  = 0,

		touchpad = {
			natural_scroll = true,
		},
	},
})
