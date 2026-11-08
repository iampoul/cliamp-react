// Shared helpers for the cliamp-react Omarchy bar plugin.
// Kept dependency-free so the same logic serves the widget and the background.

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v))
}

function setting(cfg, key, fallback) {
  if (!cfg || cfg[key] === undefined || cfg[key] === null) return fallback
  return cfg[key]
}

// Minimal TOML reader for the [bar] section only. The Python daemon owns the
// whole file; QML just needs this one section so the config stays single-source.
function parseConfig(raw) {
  var out = ({})
  var lines = String(raw || "").split("\n")
  var section = ""
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "" || line.charAt(0) === "#") continue
    if (line.charAt(0) === "[") {
      section = line.replace(/^\[\s*|\s*\]$/g, "")
      continue
    }
    if (section !== "bar") continue
    var m = line.match(/^([A-Za-z0-9_]+)\s*=\s*(.*)$/)
    if (!m) continue
    var value = m[2].replace(/\s+#.*$/, "").trim()
    if (value === "true" || value === "false") out[m[1]] = value === "true"
    else if (/^-?\d+(\.\d+)?$/.test(value)) out[m[1]] = Number(value)
    else out[m[1]] = value.replace(/^["']|["']$/g, "")
  }
  return out
}

// Smoothly interpolate the 10-band spectrum across t in 0..1.
function bandAt(bands, t) {
  if (!bands || !bands.length) return 0
  var n = bands.length
  var f = clamp(t, 0, 1) * (n - 1)
  var i = Math.floor(f)
  var frac = f - i
  var a = Number(bands[i]) || 0
  var b = Number(bands[Math.min(n - 1, i + 1)]) || 0
  return clamp(a + (b - a) * frac, 0, 1)
}

// Bass in the middle, highs at both edges — a symmetric spectrum for the
// full-width background.
function mirrored(bands, t) {
  return Math.pow(bandAt(bands, Math.abs(clamp(t, 0, 1) - 0.5) * 2), 0.8)
}

// Bass left, highs right — a readable graph for the compact widget.
function linear(bands, t) {
  return Math.pow(bandAt(bands, t), 0.8)
}
