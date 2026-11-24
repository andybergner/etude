import QtQuick
import Quickshell
import Quickshell.Io
import Etude.Ui
import "../components"

// System › Info (wie Windows): Gerät oben mit tr.t("about.rename"),
// darunter Geräte- und Etude-Spezifikationen zum Kopieren
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property var device: ({})            // { hostname, model }
    property var updates: null           // Updates.qml (Versionen)
    property var info: ({})
    property string error: ""

    signal hostnameChanged()

    spacing: 4

    // ---- Daten sammeln ----
    Process {
        running: true
        command: ["sh", "-c",
            "echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')\";" +
            "echo \"cores=$(nproc)\";" +
            "echo \"mem=$(awk '/MemTotal/{printf \"%.1f GB\", $2/1048576}' /proc/meminfo)\";" +
            "echo \"gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d controller|display' | head -n1 | cut -d: -f3- | sed 's/^ *//')\";" +
            "echo \"disk=$(df -h --output=size,avail / | tail -n1 | awk '{print $1\"|\"$2}')\";" +
            "echo \"arch=$(uname -m)\";" +
            "echo \"kernel=$(uname -r)\";" +
            "echo \"machine=$(cat /etc/machine-id 2>/dev/null)\";" +
            "echo \"installed=$(head -n1 /var/log/pacman.log 2>/dev/null | cut -c2-11)\";" +
            "echo \"hyprland=$(hyprctl version 2>/dev/null | grep -m1 -oE 'v?[0-9]+\\.[0-9]+(\\.[0-9]+)?')\";" +
            "echo \"quickshell=$(qs --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\\.[0-9]+(\\.[0-9]+)?')\";" +
            "echo \"base=$(. /etc/os-release 2>/dev/null; echo $PRETTY_NAME)\";" +
            "echo \"uptime=$(uptime -p 2>/dev/null | sed 's/^up //')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}
                for (const line of this.text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) o[line.slice(0, i)] = line.slice(i + 1).trim()
                }
                if (o.installed) {
                    const d = new Date(o.installed)
                    if (!isNaN(d)) o.installed = d.toLocaleDateString(I18n.locale, Locale.LongFormat)
                }
                root.info = o
            }
        }
    }

    Process {
        id: renameProc
        stderr: StdioCollector { id: renameErr }
        onExited: (code) => {
            if (code === 0) { renamePop.close(); root.error = ""; root.hostnameChanged() }
            else root.error = /auth|polkit|interactive/i.test(renameErr.text)
                ? tr.t("about.noPermissionInstallThePolkit")
                : (renameErr.text.trim() || tr.t("about.renamingFailed"))
        }
    }
    function rename(name) {
        name = name.trim()
        if (!/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(name)) {
            root.error = tr.t("about.onlyLettersDigitsAndHyphens")
            return
        }
        renameProc.command = ["hostnamectl", "set-hostname", name]
        renameProc.running = true
    }

    // ===== Gerät =====
    Rectangle {
        width: root.width
        height: 88
        radius: Theme.radiusLg
        color: Theme.card
        border.width: 1
        border.color: Theme.border

        Row {
            x: 20; y: 20
            spacing: 16
            Rectangle {
                width: 48; height: 48
                radius: Theme.radiusLg
                color: Theme.primary
                EtudeLogo { anchors.centerIn: parent; size: 24; monoColor: Theme.primaryForeground }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: root.device.hostname || tr.t("about.unnamed")
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.device.model || ""
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }
            }
        }
        Button {
            id: renameBtn
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: tr.t("about.rename")
            iconStart: String.fromCodePoint(0xF03EB)
            onClicked: { root.error = ""; nameInput.text = root.device.hostname || ""; renamePop.open(); nameInput.forceActiveFocus() }
        }
    }

    Dialog {
        id: renamePop
        title: tr.t("about.renameDevice")
        description: tr.t("about.theDeviceIsVisibleOn")
        Field {
            width: parent.width
            label: tr.t("about.deviceName")
            hint: tr.t("about.lettersDigitsAndHyphens")
            error: root.error
            Input {
                id: nameInput
                width: parent.width
                placeholder: tr.t("about.eGMyLaptop")
                onAccepted: root.rename(text)
            }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button { text: tr.t("about.rename"); enabled: nameInput.text.trim() !== ""; onClicked: root.rename(nameInput.text) }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: renamePop.close() }
        }
    }

    Text {
        visible: root.error !== "" && !renamePop.opened
        width: root.width
        topPadding: 4
        text: root.error
        wrapMode: Text.Wrap
        color: Theme.destructive
        font.family: Theme.fontSans
        font.pixelSize: 12
    }

    Item { width: 1; height: 8 }

    InfoCard {
        width: root.width
        title: tr.t("about.deviceSpecifications")
        icon: String.fromCodePoint(0xF0322)
        rows: [
            { label: tr.t("about.deviceName"),      value: root.device.hostname || "" },
            { label: tr.t("about.model"),          value: root.device.model || "" },
            { label: tr.t("about.processor"),       value: root.info.cpu ? (root.info.cores ? tr.t("about.cpuCores").arg(root.info.cpu).arg(root.info.cores) : root.info.cpu) : "" },
            { label: tr.t("about.graphics"),          value: root.info.gpu || "" },
            { label: tr.t("about.installedRam"), value: root.info.mem || "" },
            { label: tr.t("about.storage"),        value: root.info.disk ? tr.t("about.diskFree").arg(root.info.disk.split("|")[0]).arg(root.info.disk.split("|")[1] || "") : "" },
            { label: tr.t("about.systemType"),       value: root.info.arch ? tr.t("about.architecture").arg(root.info.arch) : "" },
            { label: tr.t("about.deviceId"),       value: root.info.machine || "" }
        ]
    }

    Item { width: 1; height: 8 }

    InfoCard {
        width: root.width
        title: tr.t("about.etudeSpecifications")
        icon: String.fromCodePoint(0xF02FD)
        rows: [
            { label: tr.t("about.edition"),       value: "Etude" },
            { label: tr.t("about.version"),       value: !root.updates ? ""
                                                     : root.updates.dev ? tr.t("about.devVersion").arg(root.updates.devVersion)
                                                     : root.updates.installed["etude"] ? tr.t("about.etudeVersion").arg(root.updates.installed["etude"]).arg(root.updates.installed["etude-ui"] || "–")
                                                     : "" },
            { label: tr.t("about.base"),         value: root.info.base || "Arch Linux" },
            { label: tr.t("about.installedOn"), value: root.info.installed || "" },
            { label: tr.t("about.kernel"),        value: root.info.kernel || "" },
            { label: "Hyprland",      value: root.info.hyprland || "" },
            { label: "Quickshell",    value: root.info.quickshell || "" },
            { label: tr.t("about.uptime"),      value: root.info.uptime || "" }
        ]
    }
}
