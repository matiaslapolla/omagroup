import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Tracks which group shows on each monitor and draws one frame per screen.
// Every state change goes through bin/omagroup, so the shell and the
// terminal behave the same.
Item {
  id: root

  readonly property string cli: String(Qt.resolvedUrl("bin/omagroup")).replace(/^file:\/\//, "")
  readonly property string prefix: "special:omagroup-"
  // Same lookup as STATE_DIR in bin/omagroup.
  readonly property string statePath: (Quickshell.env("OMAGROUP_STATE_DIR")
    || (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omagroup") + "/groups.json"

  // { "DP-1": "og1" } for each monitor that shows a group.
  property var shown: ({})
  property var groups: []

  // Toplevel objects are not deeply reactive; every event bumps this.
  property int revision: 0

  // OMAGROUP_NOTIFY makes the CLI report its errors as notifications.
  function run(args) {
    Quickshell.execDetached(["env", "OMAGROUP_NOTIFY=1", root.cli].concat(args))
  }

  function windowCount(n) {
    return n + (n === 1 ? " window" : " windows")
  }

  function groupFor(id) {
    for (var i = 0; i < root.groups.length; i++) if (root.groups[i].id === id) return root.groups[i]
    return null
  }

  function memberCount(id) {
    var _ = root.revision
    var values = Hyprland.toplevels.values
    var n = 0
    for (var i = 0; i < values.length; i++) {
      var ws = values[i].workspace
      if (ws && ws.name === root.prefix + id) n++
    }
    return n
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      root.revision++
      switch (event.name) {
      case "activespecial":
      case "focusedmon":
      case "monitoradded":
      case "monitorremoved":
      case "configreloaded":
        monitorsTimer.restart()
        break
      case "closewindow":
      case "movewindowv2":
        monitorsTimer.restart()
        if (root.groups.length) pruneTimer.restart()
        break
      }
    }
  }

  Timer {
    id: monitorsTimer
    interval: 40
    // The CLI replaces the state file by rename, which a file watch can miss.
    onTriggered: {
      monitorsQuery.running = true
      stateFile.reload()
    }
  }

  Process {
    id: monitorsQuery
    running: true
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        var next = {}
        try {
          var monitors = JSON.parse(text)
          for (var i = 0; i < monitors.length; i++) {
            var name = monitors[i].specialWorkspace ? monitors[i].specialWorkspace.name : ""
            if (name.indexOf(root.prefix) === 0) next[monitors[i].name] = name.slice(root.prefix.length)
          }
        } catch (e) {
          return
        }
        root.shown = next
      }
    }
  }

  // A group whose last member left or closed; the CLI deletes it.
  Timer {
    id: pruneTimer
    interval: 400
    onTriggered: root.run(["prune"])
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.groups = JSON.parse(text()).groups || []
      } catch (e) {
        root.groups = []
      }
    }
    onLoadFailed: root.groups = []
  }

  Variants {
    model: Quickshell.screens
    Frame {
      required property var modelData
      screen: modelData
      service: root
    }
  }

  Gallery {
    id: gallery
    service: root
    onConfirmed: function(addresses, name) {
      root.run(name ? ["create", "--name", name].concat(addresses) : ["create"].concat(addresses))
    }
  }

  IpcHandler {
    target: "omagroup"

    function pick(): void { gallery.open() }
    function cancel(): void { gallery.close() }
    function shown(): string { return JSON.stringify(root.shown) }
  }
}
