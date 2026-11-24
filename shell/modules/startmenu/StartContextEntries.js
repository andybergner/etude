// Einträge des Kontextmenüs am Start-Button (Rechtsklick), wie Win + X.
// Felder: label, shortcut (nur Anzeige), exec (Befehl per sh -c),
//         variant ("destructive"), submenu, disabled
// entries(tr): tr = Translations des Startmenüs (Texte in der Systemsprache)
.pragma library
.import "PowerEntries.js" as Power

function entries(tr) {
    return [
        { label: tr.t("startmenu.terminal"),    shortcut: "Super ↵", exec: "kitty" },
        { type: "separator" },
        { label: tr.t("startmenu.taskManager"), shortcut: tr.t("startmenu.taskManagerShortcut"), exec: "etude-taskmanager" },
        { label: tr.t("startmenu.settings"),    shortcut: "Super I", exec: "etude-settings" },
        { label: tr.t("startmenu.explorer"),    shortcut: "Super E", exec: "etude-files" },
        { type: "separator" },
        { label: tr.t("startmenu.shutDownOrSignOut"), submenu: Power.entries(tr) }
    ]
}
