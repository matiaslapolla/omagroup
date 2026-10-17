import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string label: ""
  property bool primary: false
  signal activated()

  anchors.verticalCenter: parent ? parent.verticalCenter : undefined
  width: text.implicitWidth + Style.space(28)
  height: Style.space(38)
  radius: Style.space(8)
  opacity: root.enabled ? 1 : 0.4
  color: root.primary ? Color.accent
    : hover.hovered ? Util.alpha(Color.foreground, 0.14) : Util.alpha(Color.foreground, 0.07)

  Text {
    id: text
    anchors.centerIn: parent
    text: root.label
    color: root.primary ? Color.background : Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.bold: root.primary
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: if (root.enabled) root.activated() }
}
