.pragma library
// Art einer Benachrichtigung = die drei Dringlichkeiten des freedesktop-Standards:
//   "default"  normal (Standard) → ohne Symbol
//   "low"      niedrig           → ⓘ
//   "critical" kritisch          → ⓧ (rot), bleibt stehen
//     notify-send -u low|normal|critical …
// Gespeicherte Einträge (Verlauf) tragen die Art als Feld "type".
function of(n) {
    if (!n) return "default"
    if (n.type === "low" || n.type === "critical") return n.type
    if (n.type) return "default"                            // ältere Einträge (normal, success, warning)
    if (n.urgency === 2) return "critical"                  // NotificationUrgency.Critical
    if (n.urgency === 0) return "low"                       // NotificationUrgency.Low
    return "default"
}

// Symbol (Material Design Icons, Umriss wie bei shadcn/lucide), 0 = keins
function icon(kind) {
    return kind === "critical" ? 0xF015A          // close-circle-outline  ⓧ
         : kind === "low"      ? 0xF02FD          // information-outline   ⓘ
         : 0
}
