import QtQuick
import Quickshell.Wayland
import qs.Commons

// One window in the gallery: live capture, location, process and title.
// A window that Hyprland does not render (another workspace, minimized)
// has no capture, so the card shows its app icon.
Rectangle {
  id: root

  property var entry: ({})
  property var toplevel: null
  property int captureHeight: 160
  // 1-based position in the selection, 0 when not selected.
  property int order: 0
  signal toggled()

  readonly property bool selected: root.order > 0

  height: column.implicitHeight + Style.space(16)
  radius: Math.max(Style.space(12), Style.cornerRadius)
  color: hover.hovered ? Util.alpha(Color.foreground, 0.1) : Util.alpha(Color.foreground, 0.05)
  border.width: root.selected ? 2 : 1
  border.color: root.selected ? Color.accent : Util.alpha(Color.foreground, 0.15)

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: root.toggled() }

  Column {
    id: column
    x: Style.space(8)
    y: Style.space(8)
    width: parent.width - Style.space(16)
    spacing: Style.space(8)

    Rectangle {
      width: parent.width
      height: root.captureHeight
      radius: Style.space(8)
      color: Util.alpha(Color.background, 0.6)
      clip: true

      ScreencopyView {
        id: capture
        anchors.fill: parent
        anchors.margins: Style.space(4)
        captureSource: root.toplevel && root.toplevel.wayland ? root.toplevel.wayland : null
        live: true
        paintCursor: false
      }

      AppIcon {
        anchors.centerIn: parent
        visible: !capture.hasContent
        appClass: root.entry.class || ""
        size: Math.round(root.captureHeight * 0.38)
      }

      Rectangle {
        visible: root.selected
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(8)
        width: Style.space(28)
        height: width
        radius: width / 2
        color: Color.accent

        Text {
          anchors.centerIn: parent
          text: root.order
          color: Color.background
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(8)

      Rectangle {
        id: pill
        width: locationText.implicitWidth + Style.space(14)
        height: locationText.implicitHeight + Style.space(6)
        radius: height / 2
        color: Util.alpha(Color.accent, 0.18)

        Text {
          id: locationText
          anchors.centerIn: parent
          text: root.entry.location || ""
          textFormat: Text.PlainText
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Text {
        anchors.verticalCenter: pill.verticalCenter
        width: parent.width - pill.width - parent.spacing
        text: root.entry.process || root.entry.class || ""
        textFormat: Text.PlainText
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
      }
    }

    Text {
      width: parent.width
      text: root.entry.title || ""
      textFormat: Text.PlainText
      color: Util.alpha(Color.foreground, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }
  }
}
