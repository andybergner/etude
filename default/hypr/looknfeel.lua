-- Aussehen: Abstände, Rahmen, Rundungen, Blur, Animationen
-- Die Farben kommen später aus dem Theme (Schritt 7).
-- https://wiki.hypr.land/configuring/core/config-options/

hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 10,
        border_size = 1,

        col = {
            active_border   = "rgba(a1a1aaff)",   -- zinc-400
            inactive_border = "rgba(27272aff)",   -- zinc-800
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "scrolling",   -- Standard; änderbar in Einstellungen › System › Multitasking
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = 0x66000000,
        },

        blur = {
            enabled  = true,
            size     = 4,
            passes   = 2,
            vibrancy = 0.17,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,    -- keine Anime-Wallpaper
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        -- stürzt die Shell im gesperrten Zustand ab, darf eine neu gestartete
        -- Shell den Lockscreen übernehmen (sonst bleibt nur der rote Notfallbildschirm)
        allow_session_lock_restore = true,
    },

    layers = {
        allow_new_top_layers_over_existing_fullscreen = true,
    },
})

-- Kurven
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1},  {0.32, 1} } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},     {1, 1}    } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0},  {0.1, 1}  } })
hl.curve("easy",         { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

-- Animationen: ruhig und kurz
hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 90%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 90%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
