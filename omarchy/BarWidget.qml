import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// Bar pill for cliamp-react: a music glyph with a small state dot.
// Left-click opens the control panel, Shift+left-click toggles the effect,
// middle-click cycles the motion path. State comes from `cliamp-react-ctl get`;
// every action goes back through the same ctl so config.toml is never rewritten.
BarWidget {
    id: root
    moduleName: "io.github.iampoul.cliamp-react"

    property var state: null
    property string error: ""
    property var pendingAction: null
    property var pendingEnabled: null
    property string pendingMode: ""
    property string pendingPreset: ""
    property bool refreshQueued: false

    readonly property bool enabled: pendingEnabled !== null
        ? pendingEnabled === true
        : (state ? state.effective.enabled === true : true)
    readonly property string mode: pendingMode !== ""
        ? pendingMode
        : (state ? String(state.effective.mode || "all") : "all")
    readonly property string preset: pendingPreset !== ""
        ? pendingPreset
        : (state ? String(state.preset || "config") : "config")
    readonly property bool serviceActive: state ? state.service_active === true : false
    readonly property bool busy: actionProcess.running
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

    function open() {
        if (panelLoader.item) panelLoader.item.open()
    }

    function close() {
        if (panelLoader.item) panelLoader.item.close()
    }

    function togglePanel() {
        if (panelLoader.item) panelLoader.item.toggle()
    }

    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    function closeForPopoutSwitch() {
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
    }

    function injectPanel() {
        var target = panelLoader.item
        if (!target) return
        target.bar = root.bar
        target.settings = root.settings
        target.anchorItem = pill
        target.hostWidget = root
        target.host = root
    }

    onBarChanged: root.injectPanel()
    onSettingsChanged: root.injectPanel()

    function refreshState() {
        if (getProcess.running) {
            root.refreshQueued = true
            return
        }
        getProcess.command = ["cliamp-react-ctl", "get"]
        getProcess.running = true
    }

    function apply(args) {
        if (actionProcess.running) {
            root.pendingAction = args
            return
        }
        actionProcess.command = ["cliamp-react-ctl"].concat(args)
        actionProcess.running = true
    }

    function setEnabled(value) {
        root.pendingEnabled = value === true
        root.apply(["set", "enabled", value === true ? "true" : "false"])
    }

    function toggleEnabled() {
        root.setEnabled(!root.enabled)
    }

    function setMode(value) {
        root.pendingMode = String(value)
        root.apply(["set", "mode", String(value)])
    }

    function cycleMode() {
        root.setMode(root.mode === "all" ? "bottom" : "all")
    }

    function setPreset(name) {
        root.pendingPreset = String(name)
        root.apply(["preset", String(name)])
    }

    function resetSettings() {
        root.pendingEnabled = null
        root.pendingMode = ""
        root.pendingPreset = ""
        root.apply(["reset"])
    }

    Timer {
        id: pollTimer
        interval: 8000
        repeat: true
        running: true
        onTriggered: {
            if (!root.busy) root.refreshState()
        }
    }

    Component.onCompleted: root.refreshState()

    Process {
        id: getProcess
        running: false
        command: []
        stdout: StdioCollector { id: getStdout; waitForEnd: true }
        stderr: StdioCollector { id: getStderr; waitForEnd: true }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                var parsed = Model.parseState(getStdout.text)
                if (parsed) {
                    root.state = parsed
                    root.error = ""
                    if (!actionProcess.running && !root.pendingAction) {
                        root.pendingEnabled = null
                        root.pendingMode = ""
                        root.pendingPreset = ""
                    }
                } else {
                    root.error = Model.shortError(getStderr.text, "unexpected cliamp-react-ctl output")
                }
            } else {
                root.error = Model.shortError(getStderr.text, "cliamp-react-ctl unavailable")
            }
            if (root.refreshQueued) {
                root.refreshQueued = false
                root.refreshState()
            }
        }
    }

    Process {
        id: actionProcess
        running: false
        command: []
        stdout: StdioCollector { id: actionStdout; waitForEnd: true }
        stderr: StdioCollector { id: actionStderr; waitForEnd: true }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.error = Model.shortError(actionStderr.text, "cliamp-react-ctl failed")
                root.pendingEnabled = null
                root.pendingMode = ""
                root.pendingPreset = ""
            } else {
                root.error = ""
            }
            if (root.pendingAction) {
                var next = root.pendingAction
                root.pendingAction = null
                root.apply(next)
            } else {
                root.refreshState()
            }
        }
    }

    visible: true
    implicitWidth: pill.implicitWidth + Style.space(12)
    implicitHeight: Math.max(pill.implicitHeight + Style.space(6), root.barSize)

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    Row {
        id: pill
        anchors.centerIn: parent
        spacing: Style.space(5)
        opacity: root.busy ? 0.7 : 1

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf001"
            color: root.enabled
                ? (root.bar ? root.bar.foreground : Commons.Color.foreground)
                : (root.bar ? Qt.darker(root.bar.foreground, 1.8) : "#6c7086")
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(5)
            height: width
            radius: width / 2
            color: {
                if (!root.enabled) return root.bar ? Qt.darker(root.bar.foreground, 1.9) : "#585b70"
                if (root.serviceActive) return Commons.Color.accent
                return root.bar ? Qt.darker(Commons.Color.accent, 1.7) : "#45475a"
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                root.cycleMode()
            } else if (mouse.modifiers & Qt.ShiftModifier) {
                root.toggleEnabled()
            } else {
                root.togglePanel()
            }
        }
    }
}
