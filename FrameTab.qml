import QtQuick
import qs.Commons

// One sidebar row: a member's icon and title.
Rectangle {
  id: root

  property var member: ({})
  property bool active: false
  signal activated()

  height: Style.space(34)
  radius: Style.space(6)
  color: root.active ? Util.alpha(Color.accent, 0.22)
    : mouse.containsMouse ? Util.alpha(Color.popups.text, 0.08) : "transparent"

  Row {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(8)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)

    AppIcon {
      id: icon
      anchors.verticalCenter: parent.verticalCenter
      appClass: root.member["class"] || ""
      size: Style.space(18)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - icon.width - parent.spacing
      text: root.member.title || root.member["class"] || ""
      textFormat: Text.PlainText
      color: root.active ? Color.popups.text : Util.alpha(Color.popups.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
