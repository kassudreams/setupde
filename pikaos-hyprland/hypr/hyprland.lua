-- setupde: Hyprland config for PikaOS (Hyprland 0.55+, Lua config)
-- Catppuccin Mocha look, windows float by default (Super+T tiles one).
--
-- Hyprland reloads this automatically when you save a file.
-- autostart.sh only runs when Hyprland starts (log out and in for that).
-- Reference: https://wiki.hypr.land/configuring/

require("monitors")
require("env")
require("input")
require("look")
require("windows")
require("keybinds")
require("autostart")
