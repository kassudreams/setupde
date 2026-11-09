-- setupde: Hyprland config for PikaOS (Hyprland 0.55+, Lua config)
-- Catppuccin Mocha look; every window floats and snaps (Super+arrows, Super+T).
--
-- Hyprland reloads this automatically when you save a file.
-- autostart.sh only runs when Hyprland starts (log out and in for that).
-- Reference: https://wiki.hypr.land/configuring/

-- plugins.lua only exists if install.sh found a packaged hyprbars plugin
pcall(require, "plugins")

require("monitors")
require("env")
require("input")
require("look")
require("bars")
require("snap")       -- snapping, Arrange, big / own size
require("windows")
require("game")      -- after look: game mode changes some of its settings
require("keybinds")
require("autostart")
