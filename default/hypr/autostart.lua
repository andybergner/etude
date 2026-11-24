-- Autostart
-- https://wiki.hypr.land/configuring/core/autostart/

local ETUDE = etude.home   -- aus env.lua

hl.on("hyprland.start", function()
    -- Mauszeiger setzen (Theme/Größe kommen aus env.lua bzw. den Einstellungen)
    hl.exec_cmd("hyprctl setcursor \"${XCURSOR_THEME:-Adwaita}\" \"${XCURSOR_SIZE:-24}\"")
    -- Etude-Shell: Leiste, Startmenü, Hintergrund, Sperrbildschirm
    hl.exec_cmd("qs -p " .. ETUDE .. "/shell")
    -- Zwischenablage: bleibt erhalten, wenn das Programm geschlossen wird (wl-clip-persist),
    -- und der Verlauf für Super+V (cliphist: Texte und Bilder)
    hl.exec_cmd("command -v wl-clip-persist >/dev/null && wl-clip-persist --clipboard regular")
    hl.exec_cmd("command -v cliphist >/dev/null && wl-paste --type text --watch cliphist store")
    hl.exec_cmd("command -v cliphist >/dev/null && wl-paste --type image --watch cliphist store")
    -- Apps aus dem XDG-Autostart (Einstellungen › Apps › Autostart)
    hl.exec_cmd("etude-autostart")
end)
