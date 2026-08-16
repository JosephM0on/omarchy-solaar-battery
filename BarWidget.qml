import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "josephm0on.solaar-battery"

  property var devices: []
  property bool refreshPending: false
  readonly property int refreshMs: Math.max(15, Number(setting("refreshIntervalSec", 60))) * 1000
  readonly property string label: Model.formatLabel(devices, vertical)
  readonly property string tooltip: Model.formatTooltip(devices)
  readonly property bool low: Model.anyLow(devices)

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

  visible: label !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.label
    labelVisible: !root.vertical
    hasVisualContent: root.label !== ""
    fontSize: Style.font.caption
    horizontalMargin: 8.75
    verticalPadding: 8.75
    active: root.low
    tooltipText: root.tooltip
    fixedHeight: root.vertical ? 2 * Style.bar.iconSlot : -1

    onPressed: function(b) {
      if (b === Qt.RightButton) root.openSolaar()
      else root.refresh()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.label.split("\n")

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: button.fontSize
          color: button.active && button.useActiveColor ? button.activeColor : button.foreground
        }
      }
    }
  }
}
