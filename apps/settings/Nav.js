// Navigation der Einstellungen: Kategorien (Seitenleiste) und Unterseiten.
// Die Texte stehen in default/i18n/<sprache>/settings.json: nav.<kategorie>, nav.<kategorie>.<seite>, …Desc.
// Funktionen mit tr (Translations der App) geben übersetzte Einträge mit label/desc zurück.
.pragma library

function g(cp) { return String.fromCodePoint(cp) }

var categories = [
    { id: "system", icon: g(0xF0379) },
    { id: "bluetooth", icon: g(0xF00AF) },
    { id: "network", icon: g(0xF05A9) },
    { id: "personalization", icon: g(0xF1A0D) },
    { id: "apps", icon: g(0xF003B) },
    { id: "accounts", icon: g(0xF0013) },
    { id: "time", icon: g(0xF05CA) },
    { id: "privacy", icon: g(0xF0499) },
    { id: "update", icon: g(0xF06B0) }
]

// Gruppen in der Seitenleiste (shadcn: SidebarGroup mit Label)
var groups = [
    { id: "general", items: ["system", "bluetooth", "network", "personalization"] },
    { id: "appsAccounts", items: ["apps", "accounts", "time"] },
    { id: "security", items: ["privacy", "update"] }
]

// Unterseiten je Kategorie (erscheinen als Zeilen auf der Kategorieseite)
var pages = {
    privacy: [
        { id: "firewall", icon: g(0xF0498) },
        { id: "microphone", icon: g(0xF036C) },
        { id: "camera", icon: g(0xF0100) },
        { id: "location", icon: g(0xF034E) }
    ],
    apps: [
        { id: "installed", icon: g(0xF003B) },
        { id: "defaults", icon: g(0xF0E1E) },
        { id: "startup", icon: g(0xF040A) }
    ],
    accounts: [
        { id: "info", icon: g(0xF0004) },
        { id: "signin", icon: g(0xF0306) },
        { id: "users", icon: g(0xF0849) }
    ],
    bluetooth: [
        { id: "devices", icon: g(0xF00AF) },
        { id: "mouse", icon: g(0xF037D) },
        { id: "touchpad", icon: g(0xF0741) }
    ],
    network: [
        { id: "wifi", icon: g(0xF05A9) },
        { id: "ethernet", icon: g(0xF0200) },
        { id: "vpn", icon: g(0xF0582) },
        { id: "proxy", icon: g(0xF059F) },
        { id: "advanced", icon: g(0xF0493) }
    ],
    personalization: [
        { id: "background", icon: g(0xF0976) },
        { id: "colors", icon: g(0xF0E0C) },
        { id: "lockscreen", icon: g(0xF033E) },
        { id: "taskbar", icon: g(0xF0379) }
    ],
    time: [
        { id: "datetime", icon: g(0xF00F0) },
        { id: "language", icon: g(0xF05CA) },
        { id: "keyboard", icon: g(0xF030C) }
    ],
    system: [
        { id: "display", icon: g(0xF0379) },
        { id: "sound", icon: g(0xF057E) },
        { id: "notifications", icon: g(0xF009C) },
        { id: "power", icon: g(0xF0425) },
        { id: "storage", icon: g(0xF02CA) },
        { id: "multitasking", icon: g(0xF10AC) },
        { id: "about", icon: g(0xF02FD) }
    ]
}

// Dritte Ebene: Unterseiten von Unterseiten (z. B. System › Sound › Lautstärkemixer)
var children = {
    "system/sound": [ { id: "mixer", icon: g(0xF0387) } ],
    "network/wifi": [ { id: "known", icon: g(0xF05A9) } ]
}

// Kurznamen, z. B. aus den Menüs der Leiste: etude-settings sound
var aliases = {
    sound: "system/sound", display: "system/display", power: "system/power",
    notifications: "system/notifications", benachrichtigungen: "system/notifications",
    installed: "apps/installed", deinstallieren: "apps/installed", defaults: "apps/defaults", standardapps: "apps/defaults",
    autostart: "apps/startup", startup: "apps/startup",
    firewall: "privacy/firewall", microphone: "privacy/microphone", mikrofon: "privacy/microphone",
    camera: "privacy/camera", kamera: "privacy/camera", location: "privacy/location", standort: "privacy/location",
    battery: "system/power", about: "system/about", storage: "system/storage",
    wifi: "network/wifi", wlan: "network/wifi", ethernet: "network/ethernet", lan: "network/ethernet",
    personalisierung: "personalization", wallpaper: "personalization/background",
    hintergrund: "personalization/background", colors: "personalization/colors",
    farben: "personalization/colors",
    sperrbildschirm: "personalization/lockscreen", lockscreen: "personalization/lockscreen", anmeldebildschirm: "personalization/lockscreen", datetime: "time/datetime", uhrzeit: "time/datetime",
    mixer: "system/sound/mixer", profil: "accounts/info", kennwort: "accounts/signin", password: "accounts/signin", devices: "bluetooth/devices", geraete: "bluetooth/devices",
    mouse: "bluetooth/mouse", maus: "bluetooth/mouse", touchpad: "bluetooth/touchpad", vpn: "network/vpn", proxy: "network/proxy",
    language: "time/language", sprache: "time/language", keyboard: "time/keyboard", tastatur: "time/keyboard", taskbar: "personalization/taskbar", taskleiste: "personalization/taskbar"
}

function resolve(path) {
    path = (path || "system").toLowerCase()
    if (aliases[path]) path = aliases[path]
    const [cat, sub, third] = path.split("/")
    if (!categories.some(c => c.id === cat)) return "system"
    if (sub && !(pages[cat] || []).some(p => p.id === sub)) return cat
    if (third && !(children[cat + "/" + sub] || []).some(p => p.id === third)) return cat + "/" + sub
    return [cat, sub, third].filter(x => x).join("/")
}

// ---- übersetzte Einträge ----
function tc(tr, c) { return c ? Object.assign({}, c, { label: tr.t("nav." + c.id), desc: "" }) : undefined }
function tp(tr, cat, p) { return p ? Object.assign({}, p, { label: tr.t("nav." + cat + "." + p.id), desc: tr.t("nav." + cat + "." + p.id + "Desc") }) : undefined }

function categoriesT(tr) { return categories.map(c => tc(tr, c)) }
function groupsT(tr) { return groups.map(gr => Object.assign({}, gr, { label: tr.t("nav.group." + gr.id) })) }
function pagesT(tr, cat) { return (pages[cat] || []).map(p => tp(tr, cat, p)) }
function childrenT(tr, cat, sub) { return (children[cat + "/" + sub] || []).map(p => tp(tr, cat + "." + sub, p)) }

function category(id, tr) { return tc(tr, categories.find(c => c.id === id)) }
function page(cat, sub, tr) { return tp(tr, cat, (pages[cat] || []).find(p => p.id === sub)) }
function child(cat, sub, id, tr) { return tp(tr, cat + "." + sub, (children[cat + "/" + sub] || []).find(p => p.id === id)) }

// Für die Suche: alle Kategorien und Unterseiten
function all(tr) {
    const out = []
    for (const c of categoriesT(tr)) {
        out.push({ path: c.id, label: c.label, desc: "", icon: c.icon })
        for (const p of pagesT(tr, c.id))
            out.push({ path: c.id + "/" + p.id, label: p.label, desc: c.label + " · " + p.desc, icon: p.icon })
    }
    return out
}

function search(q, tr) {
    q = q.trim().toLowerCase()
    if (!q) return []
    return all(tr).filter(e => (e.label + " " + e.desc).toLowerCase().indexOf(q) >= 0)
}
