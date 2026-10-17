import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string glyph: ""
  property string tooltip: ""
  property bool active: false
  signal activated()

  width: Style.space(26)
  height: Style.space(26)
  radius: Style.space(6)
  color: root.active || hover.hovered ? Util.alpha(Color.popups.text, 0.1) : "transparent"

  Text {
    anchors.centerIn: parent
    text: root.glyph
    color: root.active || hover.hovered ? Color.popups.text : Util.alpha(Color.popups.text, 0.6)
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; readonly property bool hovered: containsMouse; onClicked: root.activated() }

  PanelToolTip {
    visible: hover.hovered && root.tooltip !== ""
    text: root.tooltip
  }
}
