import QtQuick
import Quickshell
import Quickshell.Io
import "Spectrum.js" as S

// Service half of the cliamp-react plugin. Owns the cliamp spectrum feed and
// the shared state consumed by both the bar widget and the bar background.
// It loads at shell startup (kind: service), independently of the Python
// border daemon, so the bar keeps working even if that service is stopped.
Item {
  id: root

  // Injected by omarchy-shell; unused, but keeps the service contract explicit.
  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string configPath: home + "/.config/cliamp-react/config.toml"
  readonly property string shellJsonPath: home + "/.config/omarchy/shell.json"

  property var cfg: ({})
  property string barPosition: "top"
  property var bands: []
  property real energy: 0
  property real bass: 0
  property real beat: 0
  property bool playing: false
  property bool streamUp: false

  property real avg: 0.01
  property int lastBeat: 0

  readonly property bool enabled: S.setting(cfg, "enabled", true) !== false
  readonly property bool active: enabled && playing && streamUp
  readonly property int fadeMs: Math.max(50, S.setting(cfg, "fade_ms", 400))
  property real fade: active ? 1 : 0
  Behavior on fade {
    NumberAnimation { duration: root.fadeMs; easing.type: Easing.OutCubic }
  }

  // One config file for both halves of cliamp-react. Watched so editing
  // config.toml takes effect without restarting the shell.
  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.cfg = S.parseConfig(text())
    onLoadFailed: root.cfg = ({})
    onFileChanged: reload()
  }

  // Editors that save by swapping the inode can leave inotify watching the
  // old file. A slow re-read makes config edits reliably live without a shell
  // restart (same trick Omarchy's own agents plugin uses).
  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: configFile.reload()
  }

  // Follow the bar if the user moves it to the bottom edge.
  FileView {
    id: shellFile
    path: root.shellJsonPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var j = JSON.parse(text())
        root.barPosition = (j.bar && j.bar.position === "bottom") ? "bottom" : "top"
      } catch (e) {
        root.barPosition = "top"
      }
    }
    onLoadFailed: root.barPosition = "top"
    onFileChanged: reload()
  }

  // cliamp's own NDJSON stream. No socket client exists in QML, so this is
  // the same `visstream` output the old prototype used.
  Process {
    id: stream
    command: ["cliamp", "visstream", "--fps", "30"]
    running: true
    stdout: SplitParser {
      onRead: function(line) { root.handleLine(String(line)) }
    }
    onRunningChanged: {
      if (running) {
        root.streamUp = true
        retry.stop()
        return
      }
      root.streamUp = false
      root.bands = []
      root.energy = 0
      root.beat = 0
      retry.restart()
    }
  }

  Timer {
    id: retry
    interval: 1500
    repeat: false
    onTriggered: if (!stream.running) stream.running = true
  }

  // Exact play/pause detection (bands alone decay too slowly to be reliable).
  Process {
    id: stateProc
    command: ["cliamp", "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var j = JSON.parse(String(text || "").trim())
          root.playing = !!(j && j.state === "playing")
        } catch (e) {
          root.playing = false
        }
      }
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: if (!stateProc.running) stateProc.running = true
  }

  function handleLine(line) {
    var msg
    try { msg = JSON.parse(line) } catch (e) { return }
    if (!msg || !msg.ok || !msg.bands) return

    var raw = msg.bands
    var b = []
    for (var i = 0; i < raw.length; i++) b.push(Number(raw[i]) || 0)
    var n = b.length
    if (n === 0) return

    var third = Math.max(1, Math.floor(n / 3))
    var lo = 0, mid = 0, hi = 0
    for (i = 0; i < third; i++) lo += b[i]
    for (i = third; i < 2 * third; i++) mid += b[i]
    for (i = 2 * third; i < n; i++) hi += b[i]
    lo /= third
    mid /= Math.max(1, third)
    hi /= Math.max(1, n - 2 * third)

    var e = 0.6 * lo + 0.28 * mid + 0.12 * hi
    root.bass = lo
    // fast attack, slow release
    root.energy += (e - root.energy) * (e > root.energy ? 0.40 : 0.10)
    root.beat *= 0.88

    var now = Date.now()
    if (lo > 0.11 && lo > root.avg * 1.35 && now - root.lastBeat > 130) {
      root.lastBeat = now
      root.beat = Math.min(1, 0.35 + lo)
    }
    root.avg = root.avg * 0.95 + lo * 0.05
    root.bands = b
  }

  Component.onCompleted: stateProc.running = true

  // The reactive bar background. It lives here so it shares the spectrum with
  // the widget and stays alive even when the widget is disabled.
  BarBackground { service: root }
}
