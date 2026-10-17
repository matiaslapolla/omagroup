import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

// The header of the group shown on one screen. It sits in the top gap that
// the group's workspace rule leaves free (GAP_TOP and GAP_SIDE in
// bin/omagroup). The surface is taller than the bar so the menu has room;
// input is masked to what shows.
PanelWindow {
  id: root

  property var service: null

  readonly property int gapSide: 48
  readonly property int barTop: 14
  readonly property int barHeight: 44

  readonly property string monitorName: root.screen ? root.screen.name : ""
  readonly property string groupId: root.service && root.service.shown[root.monitorName] || ""
  readonly property var group: root.groupId ? root.service.groupFor(root.groupId) : null
  readonly property int memberCount: root.groupId ? root.service.memberCount(root.groupId) : 0
  readonly property string title: root.group ? root.group.name : root.groupId

  visible: root.groupId !== ""
  anchors { top: true; left: true; right: true }
  margins { left: root.gapSide; right: root.gapSide }
  implicitHeight: root.barTop + root.barHeight + menu.height + Style.space(8)
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  color: "transparent"
  WlrLayershell.namespace: "omagroup-frame"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  mask: Region { item: menu.open ? content : bar }

  onGroupIdChanged: menu.close()

  HyprlandFocusGrab {
    active: menu.open
    windows: [root]
    onCleared: menu.close()
  }

  function run(args) {
    if (root.groupId) root.service.run(args)
  }

  Item {
    id: content
    anchors.fill: parent

    MouseArea {
      anchors.fill: parent
      enabled: menu.open
      acceptedButtons: Qt.AllButtons
      onClicked: menu.close()
    }

    Rectangle {
      id: bar
      x: 0
      y: root.barTop
      width: parent.width
      height: root.barHeight
      radius: Math.max(Style.space(12), Style.cornerRadius)
      color: Color.popups.background
      border.width: 1
      border.color: Util.alpha(Color.accent, 0.55)

      WheelHandler {
        property real pending: 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          pending += event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x
          if (Math.abs(pending) < 120) return
          var forward = pending < 0
          pending = 0
          if (event.modifiers & Qt.ShiftModifier) root.run(["resize", root.groupId, forward ? "-0.1" : "+0.1"])
          else root.run(["scroll", root.groupId, forward ? "+col" : "-col"])
        }
      }

      Row {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(10)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰕰"
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.title
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.service ? root.service.windowCount(root.memberCount) : ""
          color: Util.alpha(Color.popups.text, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Row {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        FrameButton { glyph: "󰁍"; onActivated: root.run(["scroll", root.groupId, "-col"]) }
        FrameButton { glyph: "󰁔"; onActivated: root.run(["scroll", root.groupId, "+col"]) }
        FrameButton { glyph: "󰩨"; onActivated: root.run(["resize", root.groupId, "-0.1"]) }
        FrameButton { glyph: "󰩩"; onActivated: root.run(["resize", root.groupId, "+0.1"]) }
        FrameButton {
          id: menuButton
          glyph: "⋯"
          active: menu.open
          onActivated: menu.open ? menu.close() : menu.show()
        }
      }
    }

    FrameMenu {
      id: menu
      x: Math.min(content.width - width, menuButton.mapToItem(content, menuButton.width, 0).x - width)
      y: root.barTop + root.barHeight + Style.space(6)
      countLabel: root.service ? root.service.windowCount(root.memberCount) : ""
      onPicked: function(action) {
        menu.close()
        root.run([action, root.groupId])
      }
    }
  }
}
