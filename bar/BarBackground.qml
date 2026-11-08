import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import "Spectrum.js" as S

// A full-width reactive backdrop sitting directly behind the Omarchy bar.
// Bottom layer + Ignore exclusion: no reserved space, never steals a click.
// With `omarchy bar background glassy` the bar's own frost lets this show
// through as a soft, blurred wash; with "none" it becomes the whole bar.
Item {
  id: root
  property var service: null

  readonly property var cfg: service ? service.cfg : ({})
  readonly property bool enabled: S.setting(cfg, "background", true) !== false
  readonly property int barHeight: Commons.Style.bar.sizeHorizontal
  readonly property real gain: S.setting(cfg, "gain", 1.0)
  readonly property string position: service ? service.barPosition : "top"

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.enabled && !!root.service && root.service.enabled
      color: "transparent"
      mask: Region {}
      anchors.top: root.position !== "bottom"
      anchors.bottom: root.position === "bottom"
      anchors.left: true
      anchors.right: true
      implicitHeight: root.barHeight
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "cliamp-react-bar"

      // Always the theme's own bar colour. When paused, the reactive canvas
      // fades to zero and the bar is indistinguishable from a normal one.
      Rectangle {
        anchors.fill: parent
        color: Commons.Color.bar.background
      }

      // A permanent hairline so a transparent bar still has the theme's edge.
      Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g,
                       Commons.Color.accent.b, 0.08)
      }

      Canvas {
        id: canvas
        opacity: root.service ? root.service.fade : 0
        onOpacityChanged: requestPaint()

        // Paint at a quarter of the physical width, then stretch the item
        // horizontally. It sits behind a blurred glassy bar, so the upscale
        // is invisible and a 3840px-wide Canvas would otherwise cost much
        // more CPU while playing.
        width: Math.max(320, Math.round(panel.width / 4))
        height: root.barHeight
        canvasSize: Qt.size(Math.round(width), Math.round(height))
        transform: Scale {
          origin: Qt.point(0, 0)
          xScale: panel.width / canvas.width
        }

        onPaint: {
          var ctx = getContext("2d")
          if (!ctx) return
          var w = canvasSize.width, h = canvasSize.height
          ctx.clearRect(0, 0, w, h)

          var svc = root.service
          var bands = svc ? svc.bands : []
          var energy = svc ? svc.energy : 0
          var beat = svc ? svc.beat : 0
          var cool = Commons.Color.accent
          var hot = Commons.Color.urgent

          // 1. A colour wash that breathes with loudness and kicks on beats.
          var wash = ctx.createLinearGradient(0, 0, w, 0)
          wash.addColorStop(0, Qt.rgba(cool.r, cool.g, cool.b, 0.10 + 0.26 * energy))
          wash.addColorStop(0.5, Qt.rgba(hot.r, hot.g, hot.b, 0.06 + 0.22 * beat))
          wash.addColorStop(1, Qt.rgba(cool.r, cool.g, cool.b, 0.10 + 0.26 * energy))
          ctx.fillStyle = wash
          ctx.fillRect(0, 0, w, h)

          // 2. Mirrored spectrum along the lower edge of the bar. Colours run
          //    from the theme accent down to its red, like the window borders.
          var cols = Math.max(32, S.setting(root.cfg, "cols", Math.floor(w / 16)))
          var cw = w / cols
          var maxH = h * 0.88
          // Darker at the top, hottest along the bottom edge: the bar's text
          // sits in the middle, so it stays readable while the strip still
          // fills with colour from edge to edge.
          var grad = ctx.createLinearGradient(0, h - maxH, 0, h)
          grad.addColorStop(0, Qt.rgba(cool.r, cool.g, cool.b, 0.18))
          grad.addColorStop(0.45, Qt.rgba(cool.r, cool.g, cool.b, 0.40))
          grad.addColorStop(1, Qt.rgba(hot.r, hot.g, hot.b, 0.72))
          ctx.fillStyle = grad
          ctx.beginPath()
          for (var i = 0; i < cols; i++) {
            var v = S.mirrored(bands, (i + 0.5) / cols) * root.gain
            var bh = Math.max(0, Math.min(maxH, v * maxH * 1.6))
            ctx.rect(i * cw, h - bh, Math.max(1, cw - 1), bh)
          }
          ctx.fill()

          // 3. A dark scrim keeps the bar's text legible over the brighter
          //    spectrum. Raise `scrim` in [bar] for more contrast.
          var scrim = S.clamp(S.setting(root.cfg, "scrim", 0.15), 0, 0.8)
          if (scrim > 0) {
            var base = Commons.Color.bar.background
            ctx.fillStyle = Qt.rgba(base.r, base.g, base.b, scrim)
            ctx.fillRect(0, 0, w, h)
          }

          // 4. A faint horizon line to anchor the bar visually.
          ctx.fillStyle = Qt.rgba(hot.r, hot.g, hot.b, 0.35)
          ctx.fillRect(0, h - 1, w, 1)
        }
      }

      // Only repaint while the fade is actually visible; idle costs nothing.
      Timer {
        interval: Math.max(16, Math.round(1000 / S.setting(root.cfg, "background_fps", 12)))
        repeat: true
        running: root.enabled && !!root.service && root.service.enabled && root.service.fade > 0.01
        onTriggered: canvas.requestPaint()
      }
    }
  }
}
