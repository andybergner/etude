// Ein/Aus-Einträge – genutzt im Startmenü (Power-Button) und im Kontextmenü.
// entries(tr): tr = Translations des Startmenüs (Texte in der Systemsprache)
.pragma library

function entries(tr) {
    return [
        { label: tr.t("startmenu.signOut"),  exec: "hyprctl dispatch 'hl.dsp.exit()'" },
        { type: "separator" },
        { label: tr.t("startmenu.restart"),  exec: "systemctl reboot" },
        { label: tr.t("startmenu.shutDown"), exec: "systemctl poweroff", variant: "destructive" }
    ]
}
