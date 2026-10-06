-- Start the panel, notifications etc. once when Hyprland starts.
-- The actual list lives in autostart.sh so it's easy to edit.
hl.on("hyprland.start", function()
	hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/autostart.sh")
end)
