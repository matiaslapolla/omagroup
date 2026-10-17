import QtQuick
import qs.Commons

// A square icon button of the frame.
Rectangle {
  id: root

  property string glyph: ""
  property string hint: ""
  property bool active: false
  signal activated()

  width: Style.space(30)
  height: Style.space(30)
  radius: Style.space(8)
  color: root.active || hover.hovered ? Util.alpha(Color.popups.text, 0.12) : "transparent"

  Text {
    anchors.centerIn: parent
    text: root.glyph
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  HoverHandler { id: hover }

  TapHandler { onTapped: root.activated() }
}
