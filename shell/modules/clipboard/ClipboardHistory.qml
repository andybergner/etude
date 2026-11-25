// Zwischenablage-Verlauf wie Windows (Win+V): zuletzt kopierte Texte und Bilder.
// Speichert cliphist (Autostart: wl-paste --watch cliphist store). Klick oder Enter kopiert den
// Eintrag und fügt ihn in das vorige Fenster ein (wtype, falls installiert). Entf löscht, Esc schließt.
//   qs -p $ETUDE_HOME/shell ipc call clipboard toggle
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import Etude.Ui

Scope {
    id: root
    property Translations tr: Translations { domain: "clipboard" }   // Texte dieses Moduls

    property bool atBottom: true
    property real barHeight: 48

    property var entries: []                 // [{ line, id, text, image }]
    property bool available: true            // cliphist installiert?
    property int current: 0
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/etude-clipboard"

    function toggle() { win.visible ? close() : open() }
    function open() { current = 0; load(); win.visible = true }
    function close() { win.visible = false }

    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    // ---- Einträge laden: cliphist list, Bilder als Vorschau in $XDG_RUNTIME_DIR/etude-clipboard ----
    function load() { listProc.running = false; listProc.running = true }
    Process {
        id: listProc
        command: ["sh", "-c",
            "command -v cliphist >/dev/null 2>&1 || { echo '#missing'; exit 0; }; " +
            "mkdir -p \"$1\"; cliphist list | head -n 60 | while IFS= read -r l; do " +
            "  id=${l%%\"$(printf '\\t')\"*}; " +
            "  case $l in *'[[ binary data'*) [ -s \"$1/$id\" ] || printf '%s' \"$l\" | cliphist decode > \"$1/$id\" 2>/dev/null ;; esac; " +
            "  printf '%s\\n' \"$l\"; done", "sh", root.thumbDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text
                root.available = t.trim() !== "#missing"
                const out = []
                if (root.available) for (const l of t.split("\n")) {
                    if (!l) continue
                    const tab = l.indexOf("\t")
                    const id = tab > 0 ? l.slice(0, tab) : l
                    const text = tab > 0 ? l.slice(tab + 1) : ""
                    const image = text.indexOf("[[ binary data") >= 0 && /png|jpe?g|webp|gif|bmp/i.test(text)
                    out.push({ line: l, id: id, text: text, image: image })
                }
                root.entries = out
                root.current = Math.min(root.current, Math.max(0, out.length - 1))
            }
        }
    }

    // ---- Aktionen ----
    function choose(i) {
        const e = entries[i]
        if (!e) return
        close()
        // kopieren, dann ins vorige Fenster einfügen (über wtype, wenn vorhanden):
        // Terminals mit Strg+Umschalt+V (Strg+V ist dort kein Einfügen), alle anderen mit Strg+V
        Quickshell.execDetached(["sh", "-c",
            "printf '%s' \"$1\" | cliphist decode | wl-copy && sleep 0.15 && " +
            "command -v wtype >/dev/null 2>&1 || exit 0; " +
            "cls=$(hyprctl activewindow -j 2>/dev/null | sed -n 's/.*\"class\": *\"\\([^\"]*\\)\".*/\\1/p' | head -n1); " +
            "case \"$cls\" in " +
            "kitty|Alacritty|foot|footclient|com.mitchellh.ghostty|org.wezfurlong.wezterm|xterm|XTerm|" +
            "org.kde.konsole|konsole|org.gnome.Console|org.gnome.Terminal|gnome-terminal-server|" +
            "com.system76.CosmicTerm|Termite|st|st-256color|URxvt) " +
            "wtype -M ctrl -M shift v -m shift -m ctrl ;; " +
            "*) wtype -M ctrl v -m ctrl ;; esac", "sh", e.line])
    }
    function remove(i) {
        const e = entries[i]
        if (!e) return
        entries = entries.filter((x, j) => j !== i)
        current = Math.min(current, Math.max(0, entries.length - 1))
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete; rm -f \"$2/$3\"", "sh", e.line, root.thumbDir, e.id])
    }
    function clearAll() {
        entries = []
        Quickshell.execDetached(["sh", "-c", "cliphist wipe; rm -rf \"$1\"", "sh", root.thumbDir])
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggle() }
    }

    PanelWindow {
        id: win
        readonly property var focusedScreen: {
            const m = Hyprland.focusedMonitor
            const s = Quickshell.screens
            for (let i = 0; i < s.length; i++) if (m && s[i].name === m.name) return s[i]
            return s.length > 0 ? s[0] : null
        }
        screen: focusedScreen
        visible: false
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etude-clipboard"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) list.forceActiveFocus()

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.close() }

        FocusRoot {                          // Tastatur wie bei Windows (Pfeile, Enter, Fokus-Ring)
            anchors.fill: parent

            Surface {
                id: panel
                width: 380
                height: Math.min(520, head.height + body.height + 16)
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.atBottom ? parent.height - root.barHeight - height - 8 : root.barHeight + 8
                radius: Theme.radiusLg
                padding: 8
                Keys.onEscapePressed: root.close()
                MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons }

                // Kopf: Titel + „Alle löschen“
                Item {
                    id: head
                    width: parent.width
                    height: 40
                    Text {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.tr.t("clipboard.title")
                        color: Theme.foreground
                        font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.DemiBold
                    }
                    Button {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.entries.length > 0
                        variant: "ghost"
                        size: "sm"
                        text: root.tr.t("clipboard.clearAll")
                        onClicked: root.clearAll()
                    }
                }

                Item {
                    id: body
                    y: head.height
                    width: parent.width
                    height: root.entries.length ? Math.min(list.contentHeight, 460) : emptyText.implicitHeight + 32

                    Text {
                        id: emptyText
                        visible: root.entries.length === 0
                        anchors.centerIn: parent
                        width: parent.width - 32
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: root.tr.t(root.available ? "clipboard.empty" : "clipboard.missing")
                        color: Theme.mutedForeground
                        font.family: Theme.fontSans; font.pixelSize: 13
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        clip: true
                        spacing: 4
                        model: root.entries
                        currentIndex: root.current
                        boundsBehavior: Flickable.StopAtBounds
                        activeFocusOnTab: true
                        keyNavigationEnabled: false
                        Keys.onPressed: (e) => {
                            const i = FocusNav.listKey(e, root.entries.length, root.current)
                            if (i >= 0) { root.current = i; list.positionViewAtIndex(i, ListView.Contain); e.accepted = true; return }
                            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.choose(root.current); e.accepted = true }
                            else if (e.key === Qt.Key_Delete) { root.remove(root.current); e.accepted = true }
                            else if (e.key === Qt.Key_Escape) { root.close(); e.accepted = true }
                        }

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool active: index === root.current
                            width: list.width
                            height: modelData.image ? 120 : Math.max(44, label.implicitHeight + 24)
                            radius: Theme.radiusMd
                            color: Theme.alpha(Theme.card, 0.6)
                            border.width: active && list.activeFocus ? 2 : 1
                            border.color: active && list.activeFocus ? Theme.ring : Theme.border
                            HoverLayer { radius: row.radius; shown: rowMouse.containsMouse }

                            Text {
                                id: label
                                visible: !row.modelData.image
                                anchors.left: parent.left; anchors.leftMargin: 12
                                anchors.right: del.left; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.text
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                color: Theme.foreground
                                font.family: Theme.fontSans; font.pixelSize: 13
                            }
                            Image {
                                visible: row.modelData.image
                                anchors.left: parent.left; anchors.leftMargin: 8
                                anchors.right: del.left; anchors.rightMargin: 8
                                anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.margins: 8
                                source: row.modelData.image ? "file://" + root.thumbDir + "/" + row.modelData.id : ""
                                sourceSize: Qt.size(640, 240)
                                fillMode: Image.PreserveAspectFit
                                horizontalAlignment: Image.AlignLeft
                                asynchronous: true
                                cache: false
                            }
                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.choose(row.index)
                            }
                            // Löschen (wie das „…“ bei Windows, hier direkt)
                            Item {
                                id: del
                                anchors.right: parent.right; anchors.rightMargin: 6
                                anchors.top: parent.top; anchors.topMargin: 6
                                width: 28; height: 28
                                opacity: rowMouse.containsMouse || delMouse.containsMouse || row.active ? 1 : 0
                                Rectangle { anchors.fill: parent; radius: Theme.radiusMd; color: "transparent"
                                    HoverLayer { shown: delMouse.containsMouse } }
                                Text {
                                    anchors.centerIn: parent
                                    text: String.fromCodePoint(0xF01B4)            // delete-outline
                                    color: Theme.mutedForeground
                                    font.family: Theme.fontIcon; font.pixelSize: 16
                                }
                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.remove(row.index)
                                }
                                Tooltip { text: root.tr.t("clipboard.delete"); shown: delMouse.containsMouse }
                            }
                        }
                    }
                }
            }
        }
    }
}
