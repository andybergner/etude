-- Umgebungsvariablen
-- https://wiki.hypr.land/configuring/core/environment-variables/

-- Wo Etude liegt (ETUDE_HOME):
--   Paket:       /usr/share/etude – Programme in /usr/bin, QML-Module in /usr/lib/qt6/qml
--   Entwicklung: das Repo; bin/etude-dev-link schreibt dessen Pfad nach ~/.config/etude/dev-home.
--                Dann kommen bin/ in den PATH und qml/ in den QML_IMPORT_PATH.
-- Die anderen Dateien lesen das über die globale Tabelle `etude` (etude.home, etude.dev).
local HOME = os.getenv("HOME")
local CONFIG = os.getenv("XDG_CONFIG_HOME") or (HOME .. "/.config")

local function readLine(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    if line and line ~= "" then return line end
    return nil
end

local devHome = readLine(CONFIG .. "/etude/dev-home")
etude = {
    home = devHome or os.getenv("ETUDE_HOME") or "/usr/share/etude",
    dev = devHome ~= nil,
}
hl.env("ETUDE_HOME", etude.home)

-- PATH: default/shim vorne (xdg-open → etude-open, startet Terminal-Apps wie Neovim im Terminal),
-- im Entwicklungsmodus außerdem bin/ aus dem Repo
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
if etude.dev then path = etude.home .. "/bin:" .. path end
hl.env("PATH", etude.home .. "/default/shim:" .. path)
if etude.dev then
    hl.env("QML_IMPORT_PATH", etude.home .. "/qml")   -- Repo-Module vor den installierten
end

-- Mauszeiger (vorerst fest; Formen wie Hand/Textcursor kommen über cursor-shape)
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_SIZE", "24")

-- Qt- und GTK-Apps nativ unter Wayland
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
