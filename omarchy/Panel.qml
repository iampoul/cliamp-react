import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// Control popup for cliamp-react. All state and mutations live in BarWidget:
// this panel only renders `host.state` and calls host actions, so the pill and
// the popup never disagree. Nothing here edits config.toml; the host runs
// `cliamp-react-ctl`, which writes overrides.toml and reloads the service.
Panel {
    id: root
    moduleName: "io.github.iampoul.cliamp-react"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var host: null

    Commons.Translations {
        id: strings
        directory: Qt.resolvedUrl("i18n")
    }

    readonly property color foreground: bar && bar.foreground !== undefined
        ? bar.foreground
        : Commons.Color.foreground
    readonly property color accent: Commons.Color.accent
    readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family

    readonly property bool enabled: host ? host.enabled === true : true
    readonly property bool busy: host ? host.busy === true : false
    readonly property string mode: host ? host.mode : "all"
    readonly property string preset: host ? host.preset : "config"
    readonly property string hostError: host ? String(host.error || "") : ""
    readonly property var effective: host && host.state ? host.state.effective : ({})

    readonly property var modeOptions: [
        { value: "all", label: strings.t("mode.all") },
        { value: "bottom", label: strings.t("mode.bottom") }
    ]
    readonly property var presetOptions: [
        { value: "calm", label: strings.t("preset.calm") },
        { value: "balanced", label: strings.t("preset.balanced") },
        { value: "wild", label: strings.t("preset.wild") }
    ]

    readonly property string statusText: {
        if (hostError !== "") return hostError
        if (!host || !host.state) return strings.t("status.loading")
        if (busy) return strings.t("status.applying")
        if (!host.serviceActive) return strings.t("status.stopped")
        if (!enabled) return strings.t("status.off")
        if (preset === "custom") return strings.t("status.custom")
        return mode === "bottom" ? strings.t("status.live.bottom") : strings.t("status.live.all")
    }

    readonly property string detailsText: {
        var value = effective || ({})
        return strings.t("details")
            .arg(Model.formatNumber(value.spin, 2))
            .arg(Model.formatNumber(value.sweep, 0))
            .arg(Model.formatNumber(value.min_alpha, 0))
            .arg(Model.formatNumber(value.fps, 0))
    }

    onOpenedChanged: {
        if (opened && host) host.refreshState()
    }

    function setEnabled(next) {
        if (host) host.setEnabled(next === true)
    }

    function setMode(next) {
        if (host) host.setMode(String(next))
    }

    function setPreset(next) {
        if (host) host.setPreset(String(next))
    }

    function resetSettings() {
        if (host) host.resetSettings()
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root
        bar: root.bar
        open: root.opened
        contentWidth: Style.space(390)
        contentHeight: Style.space(392)

        Rectangle {
            anchors.fill: parent
            color: root.bar ? root.bar.background : Commons.Color.background
            radius: Style.space(10)
            border.color: Qt.darker(root.foreground, 1.8)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(8)

                // Header: identity + live status
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(34)
                    spacing: Style.space(10)

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        textFormat: Text.PlainText
                        text: "\uf001"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.title
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: strings.t("title")
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.title
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: root.statusText
                            color: root.hostError !== ""
                                ? Commons.Color.urgent
                                : Qt.darker(root.foreground, 1.45)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        textFormat: Text.PlainText
                        text: root.busy ? "…" : ""
                        color: Qt.darker(root.foreground, 1.4)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                    }
                }

                PanelSeparator { Layout.fillWidth: true }

                Toggle {
                    Layout.fillWidth: true
                    label: strings.t("toggle.label")
                    description: strings.t("toggle.description")
                    checked: root.enabled
                    enabled: !root.busy
                    foreground: root.foreground
                    accent: root.accent
                    fontFamily: root.fontFamily
                    onClicked: root.setEnabled(!root.enabled)
                }

                PanelSeparator { Layout.fillWidth: true }

                PanelSectionHeader {
                    text: strings.t("mode.label")
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                }

                ButtonGroup {
                    Layout.fillWidth: true
                    options: root.modeOptions
                    value: root.mode
                    enabled: !root.busy
                    foreground: root.foreground
                    accent: root.accent
                    fontFamily: root.fontFamily
                    onChanged: function(value) { root.setMode(value) }
                }

                PanelSectionHeader {
                    text: strings.t("preset.label")
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                }

                ButtonGroup {
                    Layout.fillWidth: true
                    options: root.presetOptions
                    value: root.preset
                    enabled: !root.busy
                    foreground: root.foreground
                    accent: root.accent
                    fontFamily: root.fontFamily
                    onChanged: function(value) { root.setPreset(value) }
                }

                Item { Layout.fillHeight: true }

                PanelSeparator { Layout.fillWidth: true }

                // Effective tuning + reset
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(28)
                    spacing: Style.space(8)

                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: root.detailsText
                        color: Qt.darker(root.foreground, 1.45)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }

                    Button {
                        text: strings.t("reset")
                        enabled: !root.busy
                        foreground: Qt.darker(root.foreground, 1.15)
                        accent: root.accent
                        fontFamily: root.fontFamily
                        fontSize: Style.font.caption
                        tooltipText: strings.t("reset.tooltip")
                        onClicked: root.resetSettings()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: strings.t("hint")
                    color: Qt.darker(root.foreground, 1.55)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                }
            }
        }
    }
}
