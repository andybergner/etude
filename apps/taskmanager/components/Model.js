// ListModel mit einem Array abgleichen, ohne die Liste neu aufzubauen:
// vorhandene Zeilen werden überschrieben (Scrollposition und Auswahl bleiben), Rest angehängt/entfernt.
.pragma library

function sync(model, rows) {
    const n = rows.length
    for (let i = 0; i < n; i++) {
        if (i < model.count) model.set(i, rows[i])
        else model.append(rows[i])
    }
    if (model.count > n) model.remove(n, model.count - n)
}
