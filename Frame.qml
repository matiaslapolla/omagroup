import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import "lib/frame.js" as F

// The panel around the group shown on one screen. The surface covers the
// work area on the Top layer, which draws above the special workspace. It
// paints the panel everywhere except over whole members, so empty parts of
// the inner area get a background and take the clicks, and partly visible
// columns stay covered. Geometry comes from `omagroup geometry` and the
// group's insets, which also size the workspace rule's gaps.
PanelWindow {
  id: root

  property var service: null

  readonly property var geometry: root.service ? root.service.geometry : null
  readonly property int pad: root.geometry ? root.geometry.pad : 0
  readonly property int header: root.geometry ? root.geometry.header : 0
  readonly property int sidebar: root.geometry ? root.geometry.sidebar : 0
  readonly property int minWidth: 640
  readonly property int minHeight: 400
  readonly property int edge: Style.space(8)
  readonly property real radius: Math.max(Style.space(12), Style.cornerRadius)

  readonly property string monitorName: root.screen ? root.screen.name : ""
  readonly property string groupId: root.service && root.service.shown[root.monitorName] || ""
  readonly property var group: root.groupId ? root.service.groupFor(root.groupId) : null
  readonly property var members: root.groupId ? root.service.membersOf(root.groupId) : []
  readonly property string title: root.group ? root.group.name : root.groupId
  readonly property var surfaceSize: ({ width: root.width, height: root.height })

  // "" when idle, "move" or an edge (n, s, e, w, ne, nw, se, sw) while dragging.
  property string dragMode: ""
  property var dragRect: null
  property point dragStart
  property var dragFrom: null

  readonly property var restRect: root.geometry
    ? F.panelRect(root.surfaceSize, F.insetsOf(root.group, root.geometry.inset))
    : { x: 0, y: 0, width: 0, height: 0 }
  readonly property var panel: root.dragRect || root.restRect
  readonly property var inner: root.geometry ? F.innerRect(root.panel, root.geometry) : root.panel
  readonly property var holes: {
    if (root.dragRect || menu.open || !root.service) return []
    var origin = root.service.origins[root.monitorName] || { x: 0, y: 0 }
    return F.holes(root.members, origin, root.inner, 2)
  }
  readonly property var tabs: F.tabOrder(root.members)

  readonly property color panelColor: {
    var c = Color.popups.background
    return Qt.rgba(c.r, c.g, c.b, 1)
  }
  readonly property color mutedText: Util.alpha(Color.popups.text, 0.7)

  function hole(i) {
    return i < root.holes.length ? root.holes[i] : { x: 0, y: 0, width: 0, height: 0 }
  }

  visible: root.groupId !== "" && root.geometry !== null
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  color: "transparent"
  WlrLayershell.namespace: "omagroup-frame"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  // Region children cannot come from a Repeater; eight holes cover three
  // columns of stacked windows.
  mask: Region {
    width: root.width
    height: root.height
    Region { intersection: Intersection.Subtract; x: root.hole(0).x; y: root.hole(0).y; width: root.hole(0).width; height: root.hole(0).height }
    Region { intersection: Intersection.Subtract; x: root.hole(1).x; y: root.hole(1).y; width: root.hole(1).width; height: root.hole(1).height }
    Region { intersection: Intersection.Subtract; x: root.hole(2).x; y: root.hole(2).y; width: root.hole(2).width; height: root.hole(2).height }
    Region { intersection: Intersection.Subtract; x: root.hole(3).x; y: root.hole(3).y; width: root.hole(3).width; height: root.hole(3).height }
    Region { intersection: Intersection.Subtract; x: root.hole(4).x; y: root.hole(4).y; width: root.hole(4).width; height: root.hole(4).height }
    Region { intersection: Intersection.Subtract; x: root.hole(5).x; y: root.hole(5).y; width: root.hole(5).width; height: root.hole(5).height }
    Region { intersection: Intersection.Subtract; x: root.hole(6).x; y: root.hole(6).y; width: root.hole(6).width; height: root.hole(6).height }
    Region { intersection: Intersection.Subtract; x: root.hole(7).x; y: root.hole(7).y; width: root.hole(7).width; height: root.hole(7).height }
  }

  onGroupIdChanged: {
    menu.close()
    root.dragMode = ""
    root.dragRect = null
  }

  // The preview stays until the state file reports the new insets.
  onRestRectChanged: if (!root.dragMode) root.dragRect = null

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
    var r = root.panel
    return x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height
  }

  // Drag lifecycle of the header and the edge bands. Points are in surface
  // coordinates; the pointer stays grabbed by this surface while the button
  // is down, even over another monitor.
  function beginDrag(mode, point) {
    root.dragStart = point
    root.dragFrom = root.restRect
    root.dragMode = mode
  }

  function updateDrag(point) {
    if (!root.dragMode) return
    var dx = point.x - root.dragStart.x
    var dy = point.y - root.dragStart.y
    if (!root.dragRect && Math.abs(dx) + Math.abs(dy) < Style.space(6)) return
    root.dragRect = F.preview(root.dragFrom, root.dragMode, dx, dy, root.surfaceSize, root.minWidth, root.minHeight)
  }

  function endDrag(point) {
    var mode = root.dragMode
    var rect = root.dragRect
    root.dragMode = ""
    if (!rect) return
    var outside = point.x < 0 || point.y < 0 || point.x >= root.width || point.y >= root.height
    if (mode === "move" && outside) {
      root.dragRect = null
      root.run(["move", root.groupId, "--cursor"])
      return
    }
    var i = F.insetsFrom(rect, root.surfaceSize)
    root.run(["frame", root.groupId, String(i.top), String(i.right), String(i.bottom), String(i.left)])
    settle.restart()
  }

  function cancelDrag() {
    root.dragMode = ""
    root.dragRect = null
  }

  // A frame command that fails leaves the old insets: drop the preview.
  Timer {
    id: settle
    interval: 1500
    onTriggered: root.dragRect = null
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

    ShapePath {
      fillColor: Util.alpha(Color.background, 0.75)
      strokeColor: "transparent"
      fillRule: ShapePath.OddEvenFill
      PathSvg {
        path: "M 0 0 H " + root.width + " V " + root.height + " H 0 Z " + F.panelPath(root.panel, root.radius, [])
      }
    }

    ShapePath {
      fillColor: root.panelColor
      strokeColor: Util.alpha(Color.popups.border, root.dragRect ? 0.9 : 0.35)
      strokeWidth: 1
      fillRule: ShapePath.OddEvenFill
      PathSvg { path: F.panelPath(root.panel, root.radius, root.holes) }
    }
  }

  // The wheel anywhere on the panel moves between columns; Shift resizes.
  Item {
    x: root.panel.x
    y: root.panel.y
    width: root.panel.width
    height: root.panel.height

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

  // Header: drag to move the group on this monitor or to another one.
  MouseArea {
    x: root.panel.x
    y: root.panel.y
    width: root.panel.width
    height: root.header
    preventStealing: true
    cursorShape: root.dragMode === "move" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    onPressed: function(mouse) { root.beginDrag("move", mapToItem(null, mouse.x, mouse.y)) }
    onPositionChanged: function(mouse) { root.updateDrag(mapToItem(null, mouse.x, mouse.y)) }
    onReleased: function(mouse) { root.endDrag(mapToItem(null, mouse.x, mouse.y)) }
    onCanceled: root.cancelDrag()
  }

  // Edge and corner bands resize the panel.
  Repeater {
    model: [
      { mode: "n", cursor: Qt.SizeVerCursor }, { mode: "s", cursor: Qt.SizeVerCursor },
      { mode: "w", cursor: Qt.SizeHorCursor }, { mode: "e", cursor: Qt.SizeHorCursor },
      { mode: "nw", cursor: Qt.SizeFDiagCursor }, { mode: "se", cursor: Qt.SizeFDiagCursor },
      { mode: "ne", cursor: Qt.SizeBDiagCursor }, { mode: "sw", cursor: Qt.SizeBDiagCursor }
    ]

    MouseArea {
      required property var modelData
      readonly property string mode: modelData.mode
      readonly property bool north: mode.indexOf("n") !== -1
      readonly property bool south: mode.indexOf("s") !== -1
      readonly property bool west: mode.indexOf("w") !== -1
      readonly property bool east: mode.indexOf("e") !== -1

      x: west ? root.panel.x - root.edge / 2 : east ? root.panel.x + root.panel.width - root.edge / 2 : root.panel.x + root.edge
      y: north ? root.panel.y - root.edge / 2 : south ? root.panel.y + root.panel.height - root.edge / 2 : root.panel.y + root.edge
      width: west || east ? root.edge : root.panel.width - 2 * root.edge
      height: north || south ? root.edge : root.panel.height - 2 * root.edge
      z: mode.length === 2 ? 2 : 1
      preventStealing: true
      hoverEnabled: true
      cursorShape: modelData.cursor
      onPressed: function(mouse) { root.beginDrag(mode, mapToItem(null, mouse.x, mouse.y)) }
      onPositionChanged: function(mouse) { if (pressed) root.updateDrag(mapToItem(null, mouse.x, mouse.y)) }
      onReleased: function(mouse) { root.endDrag(mapToItem(null, mouse.x, mouse.y)) }
      onCanceled: root.cancelDrag()
    }
  }

  Row {
    x: root.panel.x + Style.space(14)
    y: root.panel.y + Math.round((root.header - height) / 2)
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
      text: root.dragMode === "move" ? "Release here, or over another monitor"
        : root.dragMode ? "Release to resize"
        : root.service ? root.service.windowCount(root.members.length) : ""
      color: Util.alpha(Color.popups.text, 0.45)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  Row {
    id: buttons
    visible: !root.dragRect
    x: root.panel.x + root.panel.width - root.pad - width
    y: root.panel.y + Math.round((root.header - height) / 2)
    spacing: Style.space(2)

    FrameButton { glyph: "󰅁"; tooltip: "Previous column"; onActivated: root.run(["scroll", root.groupId, "-col"]) }
    FrameButton { glyph: "󰅂"; tooltip: "Next column"; onActivated: root.run(["scroll", root.groupId, "+col"]) }
    FrameButton { glyph: "󰡌"; tooltip: "Narrower column"; onActivated: root.run(["resize", root.groupId, "-0.1"]) }
    FrameButton { glyph: "󰡎"; tooltip: "Wider column"; onActivated: root.run(["resize", root.groupId, "+0.1"]) }
    FrameButton {
      glyph: "󰇘"
      tooltip: menu.open ? "" : "Group menu"
      active: menu.open
      onActivated: menu.open ? menu.close() : menu.show()
    }
  }

  // Sidebar: one tab per member, in tape order.
  Flickable {
    visible: !root.dragRect
    x: root.panel.x + root.pad
    y: root.inner.y
    width: Math.max(0, root.sidebar - 2 * root.pad)
    height: root.inner.height
    contentHeight: tabColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: tabColumn
      width: parent.width
      spacing: Style.space(2)

      Repeater {
        model: root.tabs

        FrameTab {
          required property var modelData
          width: tabColumn.width
          member: modelData
          active: root.service !== null && modelData.address === root.service.activeAddress
          onActivated: root.run(["focus", root.groupId, modelData.address])
        }
      }
    }
  }

  FrameMenu {
    id: menu
    x: buttons.x + buttons.width - width
    y: buttons.y + buttons.height + Style.space(6)
    countLabel: root.service ? root.service.windowCount(root.members.length) : ""
    onPicked: function(action) {
      menu.close()
      root.run([action, root.groupId])
    }
  }
}
