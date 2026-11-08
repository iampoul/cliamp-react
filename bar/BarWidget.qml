import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons as Commons
import "Spectrum.js" as S

// Compact spectrum inside the Omarchy bar. Idle state is a flat 2px line so
// enabling the widget never changes the bar's layout.
BarWidget {
  id: root
  moduleName: "io.github.iampoul.cliamp-react"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var cfg: service ? service.cfg : ({})
  readonly property real fade: service ? service.fade : 0
  readonly property int bars: Math.max(8, Math.min(64, S.setting(cfg, "bars", 24)))
  readonly property real gain: S.setting(cfg, "gain", 1.0)
  readonly property string clickAction: S.setting(cfg, "click", "toggle")
  readonly property bool enabled: S.setting(cfg, "enabled", true) !== false
  // The spectrum lives in the full-width bar background by default. Set
  // `widget = true` in [bar] to also show this compact graph among the widgets.
  readonly property bool widgetEnabled: S.setting(cfg, "widget", false) !== false

  visible: root.enabled && root.widgetEnabled
  implicitWidth: root.widgetEnabled ? Math.max(60, S.setting(cfg, "width", 150)) : 0
  implicitHeight: barSize

  onFadeChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    opacity: 0.25 + 0.75 * root.fade

    onPaint: {
      var ctx = getContext("2d")
      if (!ctx) return
      var w = width, h = height
      ctx.clearRect(0, 0, w, h)

      var svc = root.service
      var bands = svc ? svc.bands : []
      var cool = Commons.Color.accent
      var hot = Commons.Color.urgent
      var n = root.bars
      var gap = 2
      var bw = (w - (n - 1) * gap) / n
      var usable = h - 4

      var grad = ctx.createLinearGradient(0, 0, 0, h)
      grad.addColorStop(0, Qt.rgba(cool.r, cool.g, cool.b, 0.95))
      grad.addColorStop(1, Qt.rgba(hot.r, hot.g, hot.b, 0.95))
      ctx.fillStyle = grad
      for (var i = 0; i < n; i++) {
        var t = n > 1 ? i / (n - 1) : 0
        var v = S.linear(bands, t) * root.gain * root.fade
        var bh = Math.max(2, Math.min(usable, v * usable * 1.7))
        ctx.fillRect(i * (bw + gap), h - 2 - bh, Math.max(1, bw), bh)
      }
    }
  }

  Timer {
    interval: Math.max(16, Math.round(1000 / S.setting(root.cfg, "fps", 30)))
    repeat: true
    running: root.enabled && root.widgetEnabled && !!root.service && root.fade > 0.01
    onTriggered: canvas.requestPaint()
  }

  Process {
    id: toggle
    command: ["cliamp", "toggle"]
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    onClicked: {
      if (root.clickAction === "toggle" && !toggle.running) toggle.running = true
    }
  }
}
