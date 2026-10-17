import QtQuick
import qs.Commons

// The ⋯ menu of a frame. Close ends processes, so it asks for a second
// click on its row before it fires.
Rectangle {
  id: root

  property bool open: false
  property string countLabel: ""
  property bool confirmClose: false
  signal picked(string action)

  readonly property var rows: [
    { action: "hide", glyph: "󰖰", label: "Minimize" },
    { action: "ungroup", glyph: "󰕱", label: "Ungroup" },
    { action: "close", glyph: "󰅖", label: "Close all" }
  ]

  function show() {
    root.confirmClose = false
    root.open = true
  }

  function close() {
    root.open = false
    root.confirmClose = false
  }

  visible: root.open
  width: Style.space(260)
  height: column.implicitHeight + Style.space(12)
  radius: Math.max(Style.space(10), Style.cornerRadius)
  color: Color.popups.background
  border.width: 1
  border.color: Util.alpha(Color.popups.border, 0.45)

  Timer {
    interval: 3000
    running: root.confirmClose
    onTriggered: root.confirmClose = false
  }

  Column {
    id: column
    anchors.fill: parent
    anchors.margins: Style.space(6)

    Repeater {
      model: root.rows

      Rectangle {
        id: row
        required property var modelData
        readonly property bool armed: modelData.action === "close" && root.confirmClose

        width: column.width
        height: Style.space(34)
        radius: Style.space(6)
        color: row.armed ? Util.alpha(Color.urgent, 0.25)
          : rowHover.hovered ? Util.alpha(Color.popups.text, 0.1) : "transparent"

        Row {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.glyph
            color: row.modelData.action === "close" ? Color.urgent : Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: row.armed
              ? "Click again: close " + root.countLabel
              : row.modelData.label
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        HoverHandler { id: rowHover }

        TapHandler {
          onTapped: {
            if (row.modelData.action !== "close") root.picked(row.modelData.action)
            else if (root.confirmClose) root.picked("close")
            else root.confirmClose = true
          }
        }
      }
    }
  }
}
