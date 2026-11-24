import QtQuick
import Etude.Ui
import "../components"

// Apps › Installierte Apps (wie Windows 11): Suche, Sortierung, Liste mit Paket, Größe, Datum.
// Starten, für mich ausblenden oder deinstallieren direkt in der Zeile.
// Wo eine App installiert ist: „Für alle Benutzer“ (pacman, Flatpak systemweit) oder
// „Nur für mich“ (~/.local/share/applications, Flatpak --user).
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var apps            // AppManager.qml

    spacing: 4

    Component.onCompleted: apps.refresh()

    property string sortBy: "name"        // "name" | "size" | "date"
    property string scopeFilter: "all"    // "all" | "system" | "user"
    readonly property var shown: {
        const q = search.text.trim().toLowerCase()
        const list = apps.apps.filter(a => (scopeFilter === "all" || a.scope === scopeFilter) && !a.hiddenForMe || (scopeFilter === "all" && a.hiddenForMe))
                              .filter(a => !q || a.name.toLowerCase().indexOf(q) >= 0
                                         || (a.pkg || "").toLowerCase().indexOf(q) >= 0
                                         || (a.comment || "").toLowerCase().indexOf(q) >= 0)
        if (sortBy === "size") return list.slice().sort((a, b) => b.size - a.size)
        if (sortBy === "date") return list.slice().sort((a, b) => b.date - a.date)
        return list
    }
    property var pending: null            // App, die deinstalliert werden soll

    function details(a) {
        const parts = []
        if (a.hiddenForMe) parts.push(tr.t("apps.hiddenForMe"))
        else parts.push(tr.t(a.scope === "user" ? "apps.scopeUser" : "apps.scopeSystem"))
        if (a.flatpak) parts.push("Flatpak")
        else if (a.pkg) parts.push(a.pkg)
        else if (!a.hiddenForMe) parts.push(a.scope === "user" ? tr.t("apps.installedByTheUser") : tr.t("apps.noPackage"))
        if (a.size) parts.push(root.apps.human(a.size))
        if (a.date) parts.push(new Date(a.date).toLocaleDateString(I18n.locale, "dd.MM.yyyy"))
        return parts.join(" · ")
    }

    // ===== Suche und Sortierung =====
    Item {
        width: root.width
        height: 36
        Input {
            id: search
            anchors.left: parent.left
            anchors.right: scopeSelect.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            placeholder: tr.t("apps.searchApps")
            iconStart: String.fromCodePoint(0xF0349)
        }
        Select {
            id: scopeSelect
            anchors.right: sortSelect.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 180
            model: [{ value: "all", label: tr.t("apps.filterAll") },
                    { value: "system", label: tr.t("apps.scopeSystem") },
                    { value: "user", label: tr.t("apps.scopeUser") }]
            value: root.scopeFilter
            onActivated: (v) => root.scopeFilter = v
        }
        Select {
            id: sortSelect
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 180
            model: [{ value: "name", label: tr.t("apps.sortByName") },
                    { value: "size", label: tr.t("apps.sortBySize") },
                    { value: "date", label: tr.t("apps.sortByInstallDate") }]
            value: root.sortBy
            onActivated: (v) => root.sortBy = v
        }
    }

    Text {
        topPadding: 8
        bottomPadding: 4
        text: root.apps.loading && root.apps.apps.length === 0 ? tr.t("apps.lookingForApps")
            : tr.tn("apps.found", root.shown.length).arg(root.shown.length)
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 13
    }

    Text {
        visible: root.apps.error !== ""
        width: root.width
        bottomPadding: 4
        wrapMode: Text.Wrap
        text: root.apps.error
        color: Theme.destructive
        font.family: Theme.fontSans
        font.pixelSize: 12
    }

    Repeater {
        model: root.shown
        SettingRow {
            id: row
            required property var modelData
            width: root.width
            chevron: false
            icon: String.fromCodePoint(0xF003B)
            iconSource: root.apps.iconSource(modelData.icon)
            label: modelData.name
            desc: root.apps.busy !== "" && (root.apps.busy === modelData.pkg || root.apps.busy === modelData.flatpak) ? tr.t("apps.uninstalling") : root.details(modelData)
            opacity: modelData.hiddenForMe ? 0.7 : 1

            Item {
                width: startBtn.width; height: startBtn.height
                anchors.verticalCenter: parent.verticalCenter
                Button {
                    id: startBtn
                    variant: "ghost"
                    size: "icon-sm"
                    iconStart: String.fromCodePoint(0xF040A)
                    onClicked: root.apps.launch(row.modelData)
                }
                Tooltip { text: tr.t("apps.open"); shown: startBtn.hovered }
            }
            // Nur für mich aus- bzw. wieder einblenden (bleibt installiert)
            Item {
                width: hideBtn.width; height: hideBtn.height
                anchors.verticalCenter: parent.verticalCenter
                Button {
                    id: hideBtn
                    variant: "ghost"
                    size: "icon-sm"
                    iconStart: String.fromCodePoint(row.modelData.hiddenForMe ? 0xF0208 : 0xF0209)   // eye / eye-off
                    onClicked: root.apps.setHidden(row.modelData, !row.modelData.hiddenForMe)
                }
                Tooltip { text: tr.t(row.modelData.hiddenForMe ? "apps.showForMe" : "apps.hideForMe"); shown: hideBtn.hovered }
            }
            Item {
                width: delBtn.width; height: delBtn.height
                anchors.verticalCenter: parent.verticalCenter
                visible: root.apps.canUninstall(row.modelData)
                Button {
                    id: delBtn
                    variant: "ghost"
                    size: "icon-sm"
                    iconStart: String.fromCodePoint(0xF0A7A)
                    enabled: root.apps.busy === ""
                    onClicked: { root.pending = row.modelData; confirm.open() }
                }
                Tooltip { text: tr.t("apps.uninstall"); shown: delBtn.hovered }
            }
        }
    }

    Dialog {
        id: confirm
        title: root.pending ? tr.t("apps.uninstallQuestion").arg(root.pending.name) : ""
        description: !root.pending ? ""
            : root.pending.flatpak ? tr.t(root.pending.scope === "user" ? "apps.uninstallFlatpakUser" : "apps.uninstallFlatpakSystem").arg(root.pending.flatpak)
            : tr.t("apps.uninstallDesc").arg(root.pending.pkg)
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                variant: "destructive"
                text: tr.t("apps.uninstall")
                onClicked: { root.apps.uninstall(root.pending); confirm.close() }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: confirm.close() }
        }
    }
}
