-- Tastenkürzel – angelehnt an Windows 11
-- https://wiki.hypr.land/configuring/core/binds/

local mod         = "SUPER"
local terminal    = "kitty"
local ETUDE       = etude.home                          -- aus env.lua
local settings    = "etude-settings"                    -- Einstellungen (com.etude.settings)
local taskmanager = "etude-taskmanager"                 -- Task-Manager (com.etude.taskmanager)
local explorer    = "etude-files"                       -- Explorer (com.etude.files)
local shell       = "qs -p " .. ETUDE .. "/shell"

-- ===== Startmenü & System =====
local startmenu = hl.dsp.exec_cmd(shell .. " ipc call startmenu toggle")
hl.bind(mod .. " + SUPER_L", startmenu, { release = true })               -- Super: Startmenü
hl.bind(mod .. " + S",       startmenu)                                   -- Super+S: Suche (= Startmenü)
hl.bind(mod .. " + X", hl.dsp.exec_cmd(shell .. " ipc call startmenu context")) -- Super+X: Kontextmenü
hl.bind(mod .. " + N", hl.dsp.exec_cmd(shell .. " ipc call notifications center")) -- Super+N: Benachrichtigungen
hl.bind(mod .. " + V", hl.dsp.exec_cmd(shell .. " ipc call clipboard toggle"))     -- Super+V: Zwischenablage-Verlauf
hl.bind(mod .. " + I", hl.dsp.exec_cmd(settings))                         -- Einstellungen
hl.bind(mod .. " + L", hl.dsp.exec_cmd(shell .. " ipc call lock lock"))   -- Sperren
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(taskmanager))            -- Task-Manager

-- ===== Apps =====
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))                    -- Terminal
hl.bind(mod .. " + E",      hl.dsp.exec_cmd(explorer))                    -- Explorer

-- ===== Screenshot (wie Snipping Tool) – braucht grim, slurp, wl-clipboard =====
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind("Print",               hl.dsp.exec_cmd("grim - | wl-copy"))

-- ===== Fenster =====
hl.bind("ALT + F4",   hl.dsp.window.close())                              -- schließen
hl.bind(mod .. " + Q", hl.dsp.window.close())                             -- (zusätzlich)

-- Alt+Tab: nächstes Fenster, Alt+Shift+Tab: vorheriges
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end)
hl.bind("ALT + SHIFT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- Super+Pfeile: Fenster andocken/maximieren
hl.bind(mod .. " + Up",    hl.dsp.window.fullscreen({ mode = "maximized", action = "set" }))
hl.bind(mod .. " + Down",  hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" }))
hl.bind(mod .. " + Left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + Right", hl.dsp.window.move({ direction = "right" }))

-- Super+Shift+Pfeile: Fenster auf den anderen Monitor
hl.bind(mod .. " + SHIFT + Left",  hl.dsp.window.move({ monitor = "l" }))
hl.bind(mod .. " + SHIFT + Right", hl.dsp.window.move({ monitor = "r" }))

-- Schwebend / Vollbild
hl.bind(mod .. " + F",         hl.dsp.window.float({ action = "toggle" }))
hl.bind("F11",                 hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- ===== Desktops (= Workspaces) =====
hl.bind(mod .. " + CTRL + Left",  hl.dsp.focus({ workspace = "r-1" }))    -- vorheriger Desktop
hl.bind(mod .. " + CTRL + Right", hl.dsp.focus({ workspace = "r+1" }))    -- nächster Desktop
hl.bind(mod .. " + CTRL + D",     hl.dsp.focus({ workspace = "empty" }))  -- neuer Desktop
hl.bind(mod .. " + Tab",          hl.dsp.focus({ workspace = "previous" })) -- zuletzt genutzter

-- Super+1-9: Desktop direkt, Super+Shift+Zahl: Fenster dorthin
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Mausrad über Fenstern mit Super: Desktop wechseln
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Fenster mit der Maus verschieben / Größe ändern
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ===== Notausgang (Entwicklung): Hyprland beenden =====
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))

-- ===== Lautstärke, Helligkeit, Medien =====
-- Lautstärke, Mikrofon, Helligkeit – danach zeigt die Shell das OSD
local osd = shell .. " ipc call osd "
local function withOsd(cmd, kind) return hl.dsp.exec_cmd(cmd .. " && " .. osd .. kind) end
hl.bind("XF86AudioRaiseVolume",  withOsd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", "volume"),     { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  withOsd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "volume"),          { locked = true, repeating = true })
hl.bind("XF86AudioMute",         withOsd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "volume"),         { locked = true })
hl.bind("XF86AudioMicMute",      withOsd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", "mic"),          { locked = true })
hl.bind("XF86MonBrightnessUp",   withOsd("brightnessctl -e4 -n2 set 5%+", "brightness"),                   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", withOsd("brightnessctl -e4 -n2 set 5%-", "brightness"),                   { locked = true, repeating = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
