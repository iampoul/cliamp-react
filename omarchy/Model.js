.pragma library

// Shared vocabulary and parsing for the cliamp-react bar widget + panel.

var MODES = [
  { value: "all", labelKey: "mode.all" },
  { value: "bottom", labelKey: "mode.bottom" }
]

var PRESETS = [
  { value: "calm", labelKey: "preset.calm" },
  { value: "balanced", labelKey: "preset.balanced" },
  { value: "wild", labelKey: "preset.wild" }
]

function parseState(text) {
  var body = String(text || "").trim()
  if (body === "") return null
  try {
    var data = JSON.parse(body)
    if (!data || !data.effective) return null
    return data
  } catch (error) {
    return null
  }
}

function shortError(text, fallback) {
  var body = String(text || "").trim().split("\n")[0]
  if (body === "") body = String(fallback || "cliamp-react-ctl failed")
  return body.length > 120 ? body.slice(0, 117) + "…" : body
}

function modeLabelKey(value) {
  for (var i = 0; i < MODES.length; i++) {
    if (MODES[i].value === value) return MODES[i].labelKey
  }
  return "mode.all"
}

function presetLabelKey(value) {
  for (var i = 0; i < PRESETS.length; i++) {
    if (PRESETS[i].value === value) return PRESETS[i].labelKey
  }
  return ""
}

// Presets are known ids; anything else came from hand-edited overrides.
function isKnownPreset(value) {
  return presetLabelKey(value) !== ""
}

function formatNumber(value, digits) {
  var number = Number(value)
  if (!isFinite(number)) return "—"
  var places = digits === undefined ? 2 : digits
  var text = number.toFixed(places)
  return text.replace(/\.0+$/, "").replace(/(\.\d*?)0+$/, "$1")
}

function modeOptions() {
  return MODES
}

function presetOptions() {
  return PRESETS
}
