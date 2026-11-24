// Nerd-Font-Glyphen (Material Design Icons, nf-md-*), geprüft gegen JetBrainsMono Nerd Font
.pragma library

function g(cp) { return String.fromCodePoint(cp) }

var logo        = g(0xF0E95)   // md-circle_double (Platzhalter-Logo)
var wsActive    = g(0xF14FB)   // md-square_rounded (wie Omarchy)
var wifi        = g(0xF05A9)
var wifi1       = g(0xF091F)
var wifi2       = g(0xF0922)
var wifi3       = g(0xF0925)
var wifi4       = g(0xF0928)
var ethernet    = g(0xF0200)   // md-ethernet: Kabel
var netOff      = g(0xF0A8E)   // md-web_off: keine Verbindung
var wifiOff     = g(0xF05AA)   // md-wifi_off: WLAN ausgeschaltet
var volHigh     = g(0xF057E)
var volMedium   = g(0xF0580)
var volLow      = g(0xF057F)
var volMute     = g(0xF0581)
var bluetooth   = g(0xF00AF)
var btConnected = g(0xF00B1)
var btOff       = g(0xF00B2)
var cpu         = g(0xF061A)
var control     = g(0xF0521)   // md-toggle_switch (Kontrollzentrum)
var vpn         = g(0xF0582)
var moon        = g(0xF0F65)   // Nicht stören
var themeDark   = g(0xF050E)   // Hell/Dunkel
var nightLight  = g(0xF1A4C)
var screenshot  = g(0xF0E51)
var sun         = g(0xF00DF)
var cog         = g(0xF0493)
var lock        = g(0xF033e)
var power       = g(0xF0425)
var music       = g(0xF075A)
var prev        = g(0xF04AE)
var play        = g(0xF040A)
var pause       = g(0xF03E4)
var next        = g(0xF04AD)

// Akku in 10er-Stufen
var batteryCharging = g(0xF0084)
var batteryAlert    = g(0xF0083)
function battery(level) {
    if (level >= 95) return g(0xF0079)
    if (level < 5)   return batteryAlert
    return g(0xF007A + Math.min(8, Math.floor(level / 10) - 1 < 0 ? 0 : Math.floor(level / 10) - 1))
}
