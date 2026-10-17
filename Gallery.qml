import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// The picker: one card per open window on every workspace. Clicks select
// cards in order, and the group gets its columns in that order. With no
// screen set, the compositor opens it on the focused monitor.
PanelWindow {
  id: root

  property var service: null
  property bool opened: false
  property var windows: []
  property var selected: []
  property bool loading: false

  readonly property int cardWidth: Style.space(300)
  readonly property int captureHeight: Style.space(170)
  readonly property int pad: Style.space(28)

  signal confirmed(var addresses, string name)

  function open() {
    root.selected = []
    nameField.text = ""
    root.windows = []
    root.loading = true
    root.opened = true
    windowsQuery.running = true
    Qt.callLater(function() { nameField.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function toggle(address) {
    var next = root.selected.slice()
    var i = next.indexOf(address)
    if (i === -1) next.push(address)
    else next.splice(i, 1)
    root.selected = next
  }

  function confirm() {
    if (root.selected.length === 0) return
    root.confirmed(root.selected, nameField.text.trim())
    root.close()
  }

  function toplevelFor(address) {
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      if ("0x" + String(values[i].address).replace(/^0x/, "") === address) return values[i]
    }
    return null
  }

  Process {
    id: windowsQuery
    command: [root.service ? root.service.cli : "omagroup", "windows"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.windows = JSON.parse(text) } catch (e) { root.windows = [] }
        root.loading = false
      }
    }
  }

  visible: root.opened
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omagroup-gallery"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.94)
  }

  // Clicks on the backdrop do nothing; Escape or Cancel closes.
  MouseArea { anchors.fill: parent }

  Item {
    anchors.fill: parent
    anchors.margins: root.pad

    Row {
      id: header
      width: parent.width
      height: Style.space(48)
      spacing: Style.space(14)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰕰  Group windows"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.bold: true
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(280)
        height: Style.space(38)
        radius: Style.space(8)
        color: Util.alpha(Color.foreground, 0.08)
        border.width: 1
        border.color: nameField.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.2)

        TextInput {
          id: nameField
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          verticalAlignment: TextInput.AlignVCenter
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          maximumLength: 40
          clip: true
          Keys.onReturnPressed: root.confirm()
          Keys.onEnterPressed: root.confirm()
          Keys.onEscapePressed: root.close()

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !nameField.text
            text: "Group name (optional)"
            color: Util.alpha(Color.foreground, 0.4)
            font: nameField.font
          }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.selected.length + " selected · click cards, Enter groups, Esc cancels"
        color: Util.alpha(Color.foreground, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    Row {
      anchors.right: parent.right
      anchors.top: parent.top
      height: header.height
      spacing: Style.space(10)

      GalleryButton { label: "Cancel"; onActivated: root.close() }
      GalleryButton {
        label: "Group " + root.selected.length
        primary: true
        enabled: root.selected.length > 0
        onActivated: root.confirm()
      }
    }

    Flickable {
      anchors.top: header.bottom
      anchors.topMargin: Style.space(20)
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      contentHeight: grid.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Text {
        visible: !root.loading && root.windows.length === 0
        text: "No open windows"
        color: Util.alpha(Color.foreground, 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }

      Flow {
        id: grid
        width: parent.width
        spacing: Style.space(16)

        Repeater {
          model: root.windows

          GalleryCard {
            required property var modelData
            width: root.cardWidth
            captureHeight: root.captureHeight
            entry: modelData
            toplevel: root.opened ? root.toplevelFor(modelData.address) : null
            order: root.selected.indexOf(modelData.address) + 1
            onToggled: root.toggle(modelData.address)
          }
        }
      }
    }
  }
}
