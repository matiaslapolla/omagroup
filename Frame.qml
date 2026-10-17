import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

// The panel around the group shown on one screen. The surface covers the
// work area on the Top layer, which draws above the special workspace: the
// panel ring and the scrim hide columns that overflow the inner area. The
// inner area stays transparent and out of the input mask, so the members
// get their clicks. Geometry comes from `omagroup geometry`, which also
// sizes the workspace rule's gaps.
PanelWindow {
  id: root

  property var service: null

  readonly property var geometry: root.service ? root.service.geometry : null
  readonly property int margin: root.geometry ? root.geometry.margin : 0
  readonly property int pad: root.geometry ? root.geometry.pad : 0
  readonly property int header: root.geometry ? root.geometry.header : 0

  readonly property rect panelRect: Qt.rect(root.margin, root.margin,
    Math.max(0, root.width - 2 * root.margin), Math.max(0, root.height - 2 * root.margin))
  readonly property rect innerRect: Qt.rect(root.margin + root.pad, root.margin + root.header,
    Math.max(0, root.width - 2 * (root.margin + root.pad)),
    Math.max(0, root.height - 2 * root.margin - root.header - root.pad))
  readonly property real radius: Math.max(Style.space(12), Style.cornerRadius)

  readonly property string monitorName: root.screen ? root.screen.name : ""
  readonly property string groupId: root.service && root.service.shown[root.monitorName] || ""
  readonly property var group: root.groupId ? root.service.groupFor(root.groupId) : null
  readonly property int memberCount: root.groupId ? root.service.memberCount(root.groupId) : 0
  readonly property string title: root.group ? root.group.name : root.groupId

  readonly property color panelColor: {
    var c = Color.popups.background
    return Qt.rgba(c.r, c.g, c.b, 1)
  }
  readonly property color mutedText: Util.alpha(Color.popups.text, 0.7)
  property bool dragging: false

  visible: root.groupId !== "" && root.geometry !== null
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  color: "transparent"
  WlrLayershell.namespace: "omagroup-frame"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  mask: Region {
    width: root.width
    height: root.height
    Region {
      intersection: Intersection.Subtract
      x: root.innerRect.x
      y: root.innerRect.y
      width: menu.open ? 0 : root.innerRect.width
      height: menu.open ? 0 : root.innerRect.height
    }
  }

  onGroupIdChanged: menu.close()

  Connections {
    target: root.service
    function onMenuRequestChanged() {
      if (root.service.menuMonitor === root.monitorName && root.groupId) menu.show()
    }
  }

  HyprlandFocusGrab {
    active: menu.open
    windows: [root]
    onCleared: menu.close()
  }

  function run(args) {
    if (root.groupId) root.service.run(args)
  }

  function inPanel(x, y) {
    var r = root.panelRect
    return x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height
  }

  // A click on the scrim minimizes the group; any click closes the menu.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    onClicked: function(mouse) {
      if (menu.open) menu.close()
      else if (!root.inPanel(mouse.x, mouse.y)) root.run(["hide", root.groupId])
    }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    opacity: root.dragging ? 0.7 : 1

    ShapePath {
      fillColor: Util.alpha(Color.background, 0.75)
      strokeColor: "transparent"
      fillRule: ShapePath.OddEvenFill
      PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
      PathRectangle {
        x: root.panelRect.x; y: root.panelRect.y
        width: root.panelRect.width; height: root.panelRect.height
        radius: root.radius
      }
    }

    ShapePath {
      fillColor: root.panelColor
      strokeColor: Util.alpha(Color.popups.border, 0.35)
      strokeWidth: 1
      fillRule: ShapePath.OddEvenFill
      PathRectangle {
        x: root.panelRect.x; y: root.panelRect.y
        width: root.panelRect.width; height: root.panelRect.height
        radius: root.radius
      }
      PathRectangle {
        x: root.innerRect.x; y: root.innerRect.y
        width: root.innerRect.width; height: root.innerRect.height
      }
    }
  }

  // The wheel anywhere on the panel moves between columns; Shift resizes.
  Item {
    x: root.panelRect.x
    y: root.panelRect.y
    width: root.panelRect.width
    height: root.panelRect.height

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
  }

  // Dragging the header to another monitor moves the group there. The
  // pointer stays grabbed by this surface while the button is down, and the
  // CLI reads the drop point from `hyprctl cursorpos`.
  MouseArea {
    property point pressAt
    x: root.panelRect.x
    y: root.panelRect.y
    width: root.panelRect.width
    height: root.header
    preventStealing: true
    cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    onPressed: function(mouse) { pressAt = Qt.point(mouse.x, mouse.y) }
    onPositionChanged: function(mouse) {
      if (!root.dragging && Math.abs(mouse.x - pressAt.x) + Math.abs(mouse.y - pressAt.y) > Style.space(8)) root.dragging = true
    }
    onReleased: {
      if (!root.dragging) return
      root.dragging = false
      root.run(["move", root.groupId, "--cursor"])
    }
    onCanceled: root.dragging = false
  }

  Row {
    x: root.innerRect.x + Style.space(4)
    y: root.panelRect.y + Math.round((root.header - height) / 2)
    spacing: Style.space(8)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰕭"
      color: root.mutedText
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.title
      textFormat: Text.PlainText
      color: root.mutedText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.dragging ? "Release over a monitor to move the group"
        : root.service ? root.service.windowCount(root.memberCount) : ""
      color: Util.alpha(Color.popups.text, 0.45)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  Row {
    id: buttons
    x: root.innerRect.x + root.innerRect.width - width
    y: root.panelRect.y + Math.round((root.header - height) / 2)
    spacing: Style.space(2)

    FrameButton { glyph: "󰅁"; tooltip: "Previous column"; onActivated: root.run(["scroll", root.groupId, "-col"]) }
    FrameButton { glyph: "󰅂"; tooltip: "Next column"; onActivated: root.run(["scroll", root.groupId, "+col"]) }
    FrameButton { glyph: "󰡌"; tooltip: "Narrower column"; onActivated: root.run(["resize", root.groupId, "-0.1"]) }
    FrameButton { glyph: "󰡎"; tooltip: "Wider column"; onActivated: root.run(["resize", root.groupId, "+0.1"]) }
    FrameButton {
      glyph: "󰇘"
      tooltip: "Group menu"
      active: menu.open
      onActivated: menu.open ? menu.close() : menu.show()
    }
  }

  FrameMenu {
    id: menu
    x: buttons.x + buttons.width - width
    y: buttons.y + buttons.height + Style.space(6)
    countLabel: root.service ? root.service.windowCount(root.memberCount) : ""
    onPicked: function(action) {
      menu.close()
      root.run([action, root.groupId])
    }
  }
}
