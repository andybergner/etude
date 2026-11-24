-- Standard: jeder Monitor mit bevorzugter Auflösung, automatisch angeordnet.
-- Eigene Monitore gehören in ~/.config/hypr/hyprland.lua.
-- https://wiki.hypr.land/configuring/core/monitors/

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
