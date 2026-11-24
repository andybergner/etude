// Gemeinsame Farbpalette für Akzentfarbe und Hintergrund-Farbton
.pragma library

// "" = Standard (Akzent: Zink, Hintergrund: Anthrazit #28292d)
var colors = [
    { value: "",        label: "palette.default" },
    { value: "#3b82f6", label: "palette.blue" },
    { value: "#6366f1", label: "palette.indigo" },
    { value: "#8b5cf6", label: "palette.violet" },
    { value: "#ec4899", label: "palette.pink" },
    { value: "#ef4444", label: "palette.red" },
    { value: "#f97316", label: "palette.orange" },
    { value: "#eab308", label: "palette.yellow" },
    { value: "#22c55e", label: "palette.green" },
    { value: "#14b8a6", label: "palette.teal" }
]

// Farben mit übersetzten Namen (label im Katalog der App)
function colorsT(tr) { return colors.map(c => Object.assign({}, c, { label: tr.t(c.label) })) }

var defaultBackground = "#28292d"
