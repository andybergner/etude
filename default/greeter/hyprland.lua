-- Hyprland nur für den Etude-Anmeldebildschirm (greetd startet das über etude-greeter).
-- Keine Fenster, keine Tastenkürzel: nur der Greeter; nach der Anmeldung beendet sich Hyprland.

local ETUDE = os.getenv("ETUDE_HOME") or "/usr/share/etude"

-- Tastaturbelegung aus etude-greeter (localectl / vconsole); leer → us
local function env(name, fallback)
    local v = os.getenv(name)
    if v == nil then return fallback end
    v = v:gsub("%s", "")
    if not v:match("^[%w_-]+$") then return fallback end   -- leer, "(unset)", "n/a" …
    return v
end
local KB_LAYOUT  = env("ETUDE_GREETER_KB_LAYOUT", "us")
local KB_VARIANT = env("ETUDE_GREETER_KB_VARIANT", "")

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
-- Bildschirme wie in den Einstellungen (Auflösung, Skalierung, Anordnung) – schreibt die Shell
-- über „etude-greeter display“; fehlt die Datei, bleibt alles automatisch
local monitors = "/etc/etude/greeter/monitors.lua"
local f = io.open(monitors, "r")
if f then
    f:close()
    local ok, err = pcall(dofile, monitors)
    if not ok then print("etude: " .. monitors .. ": " .. tostring(err)) end
end

hl.config({
    input = {
        kb_layout  = KB_LAYOUT,
        kb_variant = KB_VARIANT,
        kb_options = "",
        numlock_by_default = true,
    },
    decoration = {
        blur = { enabled = true, size = 4, passes = 2 },
    },
    animations = { enabled = true },
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = 0xff18181b,
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor Adwaita 24")
    -- Greeter; endet er (Anmeldung erfolgreich), beendet sich auch dieses Hyprland
    hl.exec_cmd("sh -c 'qs -p " .. ETUDE .. "/greeter; hyprctl dispatch \"hl.dsp.exit()\" || pkill -u \"$(id -u)\" -x Hyprland'")
end)
