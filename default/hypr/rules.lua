-- Fensterregeln
-- https://wiki.hypr.land/configuring/core/rules/

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Task-Manager (btop in kitty)
hl.window_rule({
    name   = "etude-taskmanager",
    match  = { class = "^etude-taskmanager$" },
    float  = true,
    size   = { 1000, 640 },
    center = true,
})

-- Kleine Terminal-Fenster der Einstellungen (z. B. App deinstallieren)
hl.window_rule({
    name   = "etude-terminal-dialog",
    match  = { class = "^etude-terminal-dialog$" },
    float  = true,
    size   = { 820, 480 },
    center = true,
})

-- Blur hinter Leiste, Startmenü, Menüs und Kalender (wirkt nur, wenn
-- "Transparenzeffekte" in den Einstellungen an ist – sonst sind die Flächen deckend).
-- ignore_alpha: unsichtbare Klickflächen und Schatten nicht weichzeichnen.
hl.layer_rule({
    name  = "etude-blur",
    match = { namespace = "^etude-(bar|startmenu|menu|calendar|notifications|notifications-center|uac|osd)$" },
    blur  = true,
    ignore_alpha = 0.3,
})
