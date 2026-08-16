import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "solaar.battery"
  ipcTarget: "solaar.battery"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false
  property var devices: []
  property bool refreshPending: false
  readonly property var barIdentity: hostWidget || root
  readonly property int refreshMs: Math.max(15, Number(setting("refreshIntervalSec", 60))) * 1000
  readonly property bool hasDevices: devices.length > 0
  readonly property bool low: Model.anyLow(devices)
  readonly property string label: Model.barBatteryIcon(devices)
  readonly property color dim: Qt.darker(barForeground, 1.45)

  function open() {
    openedFromHotkey = false
    root.controller.show()
    root.refresh()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    root.refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refresh() {
    if (solaarProc.running) {
      refreshPending = true
      return
    }
    refreshPending = false
    solaarProc.running = true
  }

  function openSolaar() {
    if (!root.bar) return
    root.bar.run("command -v solaar >/dev/null && solaar || flatpak run io.github.pwr_solaar.solaar")
  }

  IpcHandler {
    target: "solaar.battery"

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  Process {
    id: solaarProc
    command: ["bash", "-lc", "command -v solaar >/dev/null && exec solaar show; exec flatpak run io.github.pwr_solaar.solaar show"]
    onRunningChanged: {
      if (running) {
        stallTimer.restart()
        return
      }
      stallTimer.stop()
      if (root.refreshPending) root.refresh()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.devices = Model.parseSolaarShow(text)
    }
  }

  Timer {
    id: stallTimer
    interval: 40000
    onTriggered: solaarProc.running = false
  }

  Timer {
    interval: root.refreshMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Column {
          width: parent.width
          spacing: Style.space(2)

          Text {
            text: "Logitech"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            text: root.hasDevices ? (root.devices.length + " DEVICES") : "NO DEVICES"
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
          }
        }

        Repeater {
          model: root.devices

          Column {
            required property var modelData
            width: column.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(kindIcon.implicitHeight, nameCol.implicitHeight, percentLabel.implicitHeight)

              Text {
                id: kindIcon
                text: Model.deviceIcon(modelData.kind)
                color: Model.isLow(modelData) ? (root.bar ? root.bar.urgent : Color.urgent) : root.barForeground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.heading
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                id: nameCol
                anchors.left: kindIcon.right
                anchors.leftMargin: Style.space(12)
                anchors.right: percentLabel.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: modelData.shortName
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: {
                    var bits = [Model.kindLabel(modelData.kind)]
                    var status = Model.statusLabel(modelData.status)
                    if (status) bits.push(status)
                    if (modelData.millivolt != null) bits.push(modelData.millivolt + " mV")
                    return bits.join(" · ")
                  }
                  color: root.dim
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Text {
                id: percentLabel
                text: Model.displayPercent(modelData) + "%"
                color: Model.isLow(modelData) ? (root.bar ? root.bar.urgent : Color.urgent) : root.barForeground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Item {
              width: parent.width
              implicitHeight: Style.space(6)

              Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
              }

              Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: height / 2
                color: Model.isLow(modelData)
                  ? (root.bar ? root.bar.urgent : Color.urgent)
                  : root.barForeground
                width: Math.max(parent.height, parent.width * Model.displayPercent(modelData) / 100)
              }
            }
          }
        }

        Text {
          visible: !root.hasDevices
          width: parent.width
          text: "No Logitech battery devices found"
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        PanelSeparator {
          visible: root.hasDevices
          foreground: root.barForeground
        }

        Text {
          visible: root.hasDevices
          width: parent.width
          text: "Right-click the icon to open Solaar"
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
