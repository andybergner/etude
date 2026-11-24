-- Eingabe: Tastatur, Maus, Touchpad
-- https://wiki.hypr.land/configuring/core/config-options/

-- Tastaturlayout des Systems (setzt der Etude-Installer bzw. localectl set-x11-keymap),
-- sonst deutsch. Eine Auswahl in den Einstellungen (Zeit & Sprache › Tastatur) gilt danach zusätzlich.
local function systemKeyboard()
    local f = io.open("/etc/X11/xorg.conf.d/00-keyboard.conf", "r")
    if not f then return nil, nil end
    local text = f:read("*a")
    f:close()
    local layout = text:match('Option%s+"XkbLayout"%s+"([^"]+)"')
    local variant = text:match('Option%s+"XkbVariant"%s+"([^"]*)"')
    if layout and layout:match("^[%w_,-]+$") then return layout, variant or "" end
    return nil, nil
end
local sysLayout, sysVariant = systemKeyboard()

hl.config({
    input = {
        kb_layout  = sysLayout or "de",
        kb_variant = sysVariant or "",
        kb_options = "",

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = true,
        },
    },
})

-- 3 Finger wischen = Workspace wechseln
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
