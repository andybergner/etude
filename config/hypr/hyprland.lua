-- Deine persönliche Hyprland-Config.
-- Zuerst werden die Etude-Defaults geladen, danach kommen deine Änderungen.
-- Was hier steht, überschreibt die Defaults.

require("etude/init")

-- Was du in den Etude-Einstellungen änderst (z. B. Fenster-Layout).
-- Die Datei schreibt die Settings-App: ~/.config/hypr/etude-settings.lua
pcall(require, "etude-settings")

------------------------------
---- EIGENE ÄNDERUNGEN    ----
------------------------------

-- Beispiel: größere Abstände
-- hl.config({ general = { gaps_out = 16 } })

-- Beispiel: eigener Monitor
-- hl.monitor({ output = "Virtual-1", mode = "1920x1080@60", position = "0x0", scale = 1 })
