import QtQuick
import Etude.Ui
import "../components"

// Datenschutz & Sicherheit › Firewall (ufw), Aufbau wie Windows-Sicherheit:
// Status oben, Schalter, Standardrichtlinien, darunter die Regeln mit Hinzufügen/Löschen.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var privacy         // Privacy.qml

    spacing: 4

    Component.onCompleted: privacy.refreshFirewall()

    function g(cp) { return String.fromCodePoint(cp) }
    function actionLabel(a) {
        const u = (a || "").toUpperCase()
        const out = /OUT|AUS/.test(u)
        const lab = (k) => out ? tr.t("firewall.outgoing").arg(tr.t(k)) : tr.t(k)
        if (/ALLOW|ERLAUB/.test(u)) return lab("firewall.allow")
        if (/LIMIT|BEGRENZ/.test(u)) return lab("firewall.limit")
        if (/REJECT|ZURÜCK/.test(u)) return lab("firewall.reject")
        if (/DENY|VERWEIGER|ABLEHN/.test(u)) return lab("firewall.deny")
        return a
    }
    function policyLabel(p) {
        return p === "deny" ? tr.t("firewall.policyDeny") : p === "allow" ? tr.t("firewall.policyAllow") : p === "reject" ? tr.t("firewall.policyReject") : (p || "–")
    }
    function ipLabel(g) { return tr.t(g.v4 && g.v6 ? "firewall.ipBoth" : g.v6 ? "firewall.ipv6Only" : "firewall.ipv4Only") }
    function fromLabel(f) { return /^(Anywhere|Überall)/i.test(f) ? tr.t(/v6/.test(f) ? "firewall.anywhereV6" : "firewall.anywhere") : f }

    // ===== Status =====
    Rectangle {
        width: root.width
        height: 88
        radius: Theme.radiusLg
        color: Theme.card
        border.width: 1
        border.color: Theme.border

        Rectangle {
            id: badge
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 48; height: 48
            radius: 24
            color: root.privacy.fwEnabled ? Theme.alpha(Theme.primary, 0.15) : Theme.alpha(Theme.destructive, 0.15)
            Text {
                anchors.centerIn: parent
                text: root.g(root.privacy.fwEnabled ? 0xF0498 : 0xF099D)
                color: root.privacy.fwEnabled ? Theme.primary : Theme.destructive
                font.family: Theme.fontIcon; font.pixelSize: 24
            }
        }
        Column {
            anchors.left: badge.right
            anchors.leftMargin: 16
            anchors.right: mainBtn.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: !root.privacy.ufwInstalled ? tr.t("firewall.noFirewallInstalled")
                    : root.privacy.fwEnabled ? tr.t("firewall.firewallIsOn") : tr.t("firewall.firewallIsOff")
                color: Theme.foreground
                font.family: Theme.fontSans; font.pixelSize: 16; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: !root.privacy.ufwInstalled ? tr.t("firewall.ufwProtectsTheDeviceAgainst")
                    : root.privacy.fwEnabled ? tr.t("firewall.policies").arg(root.policyLabel(root.privacy.fwIncoming)).arg(root.policyLabel(root.privacy.fwOutgoing))
                    : tr.t("firewall.theDeviceIsNotProtected")
                color: Theme.mutedForeground
                font.family: Theme.fontSans; font.pixelSize: 13
            }
        }
        Button {
            id: mainBtn
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.privacy.ufwInstalled
            text: root.privacy.fwBusy ? tr.t("firewall.installing") : tr.t("firewall.installAndTurnOn")
            enabled: !root.privacy.fwBusy
            onClicked: root.privacy.installUfw()
        }
    }

    Text {
        visible: root.privacy.fwError !== ""
        width: root.width
        topPadding: 4
        wrapMode: Text.Wrap
        text: root.privacy.fwError
        color: Theme.destructive
        font.family: Theme.fontSans; font.pixelSize: 12
    }

    Item { width: 1; height: 8 }

    SettingRow {
        width: root.width
        visible: root.privacy.ufwInstalled
        chevron: false
        icon: root.g(0xF0498)
        label: tr.t("firewall.firewall")
        desc: tr.t("firewall.filterIncomingConnectionsUfw")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.privacy.fwEnabled
            enabled_: !root.privacy.fwBusy
            onToggled: root.privacy.setFirewall(!root.privacy.fwEnabled)
        }
    }

    // ===== Regeln =====
    Item {
        visible: root.privacy.ufwInstalled
        width: root.width
        height: rulesTitle.implicitHeight
        SectionTitle { id: rulesTitle; text: tr.t("firewall.rules") }
        Button {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            variant: "outline"
            size: "sm"
            iconStart: root.g(0xF0415)
            text: tr.t("firewall.addRule")
            enabled: !root.privacy.fwBusy
            onClicked: root.openEditor(null)
        }
    }

    Rectangle {
        visible: root.privacy.ufwInstalled && root.privacy.fwRules.length === 0
        width: root.width
        height: 64
        radius: Theme.radiusMd
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        Text {
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.privacy.fwEnabled ? tr.t("firewall.noCustomRulesAllIncoming")
                                         : tr.t("firewall.rulesAreShownOnceThe")
            color: Theme.mutedForeground
            font.family: Theme.fontSans; font.pixelSize: 13
        }
    }

    Repeater {
        model: root.privacy.ufwInstalled ? root.privacy.fwRules : []
        SettingRow {
            id: row
            required property var modelData
            width: root.width
            chevron: false
            icon: root.g(/ALLOW|ERLAUB/i.test(modelData.action) ? 0xF05E0 : 0xF0156)
            label: (modelData.comment ? modelData.comment + "  ·  " : "") + modelData.to
            desc: tr.t("firewall.ruleDesc").arg(root.actionLabel(modelData.action)).arg(root.fromLabel(modelData.from)).arg(root.ipLabel(modelData))
            Item {
                visible: row.modelData.editable
                width: editBtn.width; height: editBtn.height
                anchors.verticalCenter: parent.verticalCenter
                Button {
                    id: editBtn
                    variant: "ghost"
                    size: "icon-sm"
                    iconStart: root.g(0xF03EB)
                    enabled: !root.privacy.fwBusy
                    onClicked: root.openEditor(row.modelData)
                }
                Tooltip { text: tr.t("firewall.editRule"); shown: editBtn.hovered }
            }
            Item {
                width: delBtn.width; height: delBtn.height
                anchors.verticalCenter: parent.verticalCenter
                Button {
                    id: delBtn
                    variant: "ghost"
                    size: "icon-sm"
                    iconStart: root.g(0xF0A7A)
                    enabled: !root.privacy.fwBusy
                    onClicked: root.privacy.deleteRule(row.modelData)
                }
                Tooltip { text: tr.t("firewall.deleteRule"); shown: delBtn.hovered }
            }
        }
    }

    // ===== Regel hinzufügen / bearbeiten =====
    property var editing: null            // Regelgruppe, die bearbeitet wird (null = neu)

    function openEditor(g) {
        root.editing = g
        portInput.text = g ? g.port : ""
        protoSel.value = g ? g.proto : "tcp"
        actionSel.value = g ? (/LIMIT|BEGRENZ/i.test(g.action) ? "limit" : /DENY|VERWEIGER|ABLEHN|REJECT/i.test(g.action) ? "deny" : "allow") : "allow"
        ipSel.value = g ? (g.v4 && g.v6 ? "both" : g.v6 ? "v6" : "v4") : "v4"
        commentInput.text = g ? g.comment : ""
        ruleDialog.open()
        portInput.forceActiveFocus()
    }

    Dialog {
        id: ruleDialog
        title: root.editing ? tr.t("firewall.editRule") : tr.t("firewall.addRule")
        description: tr.t("firewall.setsHowIncomingConnectionsTo")

        readonly property string port: portInput.text.trim()
        readonly property bool isRange: port.indexOf(":") >= 0
        readonly property bool portValid: /^\d{1,5}(:\d{1,5})?$/.test(port)
            && port.split(":").every(p => +p >= 1 && +p <= 65535)
        // ufw verlangt bei Portbereichen ein Protokoll
        readonly property string portError: port === "" ? ""
            : !portValid ? tr.t("firewall.invalidPort165535")
            : isRange && protoSel.value === "" ? tr.t("firewall.chooseTcpOrUdpFor")
            : ""
        readonly property bool valid: portValid && portError === ""

        Field {
            width: parent.width
            label: tr.t("firewall.port")
            hint: tr.t("firewall.singlePortLike22Or")
            error: ruleDialog.portError
            Input { id: portInput; width: parent.width; placeholder: "z. B. 22"; onAccepted: saveBtn.clicked() }
        }
        Row {
            width: parent.width
            spacing: 12
            Field {
                width: (parent.width - 12) / 2
                label: tr.t("firewall.protocol")
                Select {
                    id: protoSel
                    width: parent.width
                    model: [{ value: "tcp", label: "TCP" }, { value: "udp", label: "UDP" }, { value: "", label: tr.t("firewall.tcpAndUdp") }]
                    value: "tcp"
                    onActivated: (v) => protoSel.value = v
                }
            }
            Field {
                width: (parent.width - 12) / 2
                label: tr.t("firewall.action")
                Select {
                    id: actionSel
                    width: parent.width
                    model: [{ value: "allow", label: tr.t("firewall.allow") }, { value: "deny", label: tr.t("firewall.block") },
                            { value: "limit", label: tr.t("firewall.limit") }]
                    value: "allow"
                    onActivated: (v) => actionSel.value = v
                }
            }
        }
        Field {
            width: parent.width
            label: tr.t("firewall.ipVersion")
            hint: ipSel.value === "v4" ? tr.t("firewall.noAdditionalIpv6RuleIs")
                : ipSel.value === "v6" ? tr.t("firewall.appliesToIpv6ConnectionsOnly")
                : tr.t("firewall.ufwCreatesOneRuleEach")
            Select {
                id: ipSel
                width: parent.width
                model: [{ value: "v4", label: tr.t("firewall.ipv4Only") }, { value: "both", label: tr.t("firewall.ipv4AndIpv6") }, { value: "v6", label: tr.t("firewall.ipv6Only") }]
                value: "v4"
                onActivated: (v) => ipSel.value = v
            }
        }
        Field {
            width: parent.width
            label: tr.t("firewall.descriptionOptional")
            Input { id: commentInput; width: parent.width; placeholder: tr.t("firewall.eGSsh") }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                id: saveBtn
                text: root.editing ? I18n.t("common.save") : I18n.t("common.add")
                enabled: ruleDialog.valid
                onClicked: {
                    if (!ruleDialog.valid) return
                    const r = { action: actionSel.value, port: ruleDialog.port, proto: protoSel.value,
                                ipv: ipSel.value, comment: commentInput.text.trim() }
                    if (root.editing) root.privacy.editRule(root.editing, r)
                    else root.privacy.addRule(r)
                    ruleDialog.close()
                }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: ruleDialog.close() }
        }
    }
}
