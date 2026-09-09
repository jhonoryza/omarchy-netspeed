import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget showing live network throughput:
//   down arrow + download rate, up arrow + upload rate.
// Rates are deltas between successive netspeed.sh samples (raw /sys byte
// counters + timestamp), so the script stays stateless and the widget owns
// all rate math. First sample after (re)start or interface switch only seeds
// the baseline and shows 0 instead of manufacturing a spike.
BarWidget {
  id: root
  moduleName: "vm.netspeed"

  property real downRate: 0 // bytes/sec
  property real upRate: 0 // bytes/sec
  property string iface: ""
  property bool offline: false

  property real prevRx: 0
  property real prevTx: 0
  property real prevTime: 0
  property string prevIface: ""

  readonly property int refreshSeconds: Math.max(1, Math.min(5, Number(setting("refreshSeconds", 1)) || 1))
  readonly property bool showUpload: setting("showUpload", true) !== false

  function fmt(bps) {
    if (!(bps > 0)) return "0 B/s"
    if (bps < 1024) return Math.round(bps) + " B/s"
    if (bps < 1048576) return (bps / 1024).toFixed(1) + " KB/s"
    if (bps < 1073741824) return (bps / 1048576).toFixed(1) + " MB/s"
    return (bps / 1073741824).toFixed(2) + " GB/s"
  }

  // Fixed width so the bar never shifts as numbers grow/shrink: size both
  // value slots once from the widest string we can render, then right-align
  // the live values inside those slots.
  readonly property real valueWidth: measureValue.implicitWidth
  readonly property real iconWidth: measureIcon.implicitWidth
  readonly property real groupWidth: iconWidth + 4 + valueWidth
  readonly property real fixedRowWidth: showUpload ? groupWidth * 2 + 8 : groupWidth

  Text {
    id: measureValue
    visible: false
    text: "999.9 MB/s"
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }

  Text {
    id: measureIcon
    visible: false
    text: "󰇚"
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  readonly property string downText: offline ? "--" : fmt(downRate)
  readonly property string upText: offline ? "--" : fmt(upRate)
  readonly property string tooltip: offline
    ? "No connection"
    : (iface !== "" ? iface + "  •  " : "") + "↓ " + fmt(downRate) + "   ↑ " + fmt(upRate)

  function apply(line) {
    let data
    try {
      data = JSON.parse(String(line).trim())
    } catch (e) {
      return
    }
    if (!data || data.state === "offline") {
      root.offline = true
      root.iface = ""
      root.downRate = 0
      root.upRate = 0
      root.prevTime = 0
      root.prevIface = ""
      return
    }
    root.offline = false
    root.iface = data.iface || ""
    const rx = Number(data.rx) || 0
    const tx = Number(data.tx) || 0
    const now = Number(data.time) || 0
    if (root.prevTime > 0 && now > root.prevTime && root.prevIface === root.iface) {
      const dt = (now - root.prevTime) / 1e9
      if (dt > 0) {
        root.downRate = Math.max(0, (rx - root.prevRx) / dt)
        root.upRate = Math.max(0, (tx - root.prevTx) / dt)
      }
    } else {
      root.downRate = 0
      root.upRate = 0
    }
    root.prevRx = rx
    root.prevTx = tx
    root.prevTime = now
    root.prevIface = root.iface
  }

  function refresh() {
    if (!probe.running) probe.running = true
  }

  visible: true
  implicitWidth: root.vertical ? Style.bar.statusSlot : (root.fixedRowWidth + 16)
  // Full bar height like the WidgetButton-based neighbors (clock, keyboard
  // layout, 9router): module slots stack widgets top-aligned in the bar row,
  // so a shorter statusSlot box would float above the shared center line.
  implicitHeight: root.vertical ? (col.implicitHeight + 12) : root.barSize

  IpcHandler {
    target: "vm.netspeed"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: probe
    command: ["/bin/bash", Qt.resolvedUrl("netspeed.sh").toString().replace("file://", "")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }

  Timer {
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Horizontal bar: " down  up" in one row. Each value lives in a fixed-width
  // slot measured once from the widest string, so the row keeps a constant
  // width as speeds rise and fall. Values are right-aligned inside the slot.
  Row {
    id: row
    visible: !root.vertical
    anchors.centerIn: parent
    width: root.fixedRowWidth
    spacing: 8

    Row {
      width: root.groupWidth
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter

      Text {
        width: root.iconWidth
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "󰇚"
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: Color.accent
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        width: root.valueWidth
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: root.downText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        color: Color.foreground
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Row {
      visible: root.showUpload
      width: root.groupWidth
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter

      Text {
        width: root.iconWidth
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "󰕒"
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: Color.accent
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        width: root.valueWidth
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: root.upText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        color: Color.foreground
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // Vertical bar: stacked compact labels.
  Column {
    id: col
    visible: root.vertical
    anchors.centerIn: parent
    spacing: 2

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "↓ " + root.downText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: Color.foreground
    }

    Text {
      visible: root.showUpload
      anchors.horizontalCenter: parent.horizontalCenter
      text: "↑ " + root.upText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: Color.foreground
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        const entry = {
          id: root.moduleName
        }
        for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
        entry.showUpload = !root.showUpload
        root.settings = entry
        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
          root.bar.shell.updateEntryInline(root.moduleName, entry)
      } else {
        root.refresh()
      }
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltip)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
