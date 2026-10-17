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
  readonly property bool anyShown: Object.keys(root.shown).length > 0
  // { "DP-1": { x, y } }: the top-left of each monitor's work area, in
  // global logical px. A frame surface starts there.
  property var origins: ({})
  // { "og1": [client, ...] } from `hyprctl clients -j`, for shown groups.
  property var members: ({})
  property string activeAddress: ""
  property var groups: []
  // From `omagroup geometry`; frames stay hidden until it loads.
  property var geometry: null
  // Bumped by the IPC function `menu`; the frame on menuMonitor opens its menu.
  property int menuRequest: 0
  property string menuMonitor: ""

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

  function membersOf(id) {
    return root.members[id] || []
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (root.anyShown) clientsTimer.restart()
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

  Timer {
    id: clientsTimer
    interval: 30
    onTriggered: clientsQuery.running = true
  }

  // Scroll animations move the members without any event.
  Timer {
    interval: 300
    repeat: true
    running: root.anyShown
    onTriggered: clientsQuery.running = true
  }

  Process {
    id: clientsQuery
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        var clients
        try { clients = JSON.parse(text) } catch (e) { return }
        var next = {}
        var active = ""
        for (var i = 0; i < clients.length; i++) {
          var c = clients[i]
          var ws = c.workspace ? c.workspace.name : ""
          if (ws.indexOf(root.prefix) !== 0) continue
          var id = ws.slice(root.prefix.length)
          if (!next[id]) next[id] = []
          next[id].push({ address: c.address, class: c["class"], title: c.title, at: c.at, size: c.size })
          if (c.focusHistoryID === 0) active = c.address
        }
        // A string compare keeps bindings quiet when nothing moved.
        if (JSON.stringify(next) !== JSON.stringify(root.members)) root.members = next
        root.activeAddress = active
      }
    }
  }

  Process {
    id: monitorsQuery
    running: true
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        var next = {}
        var origins = {}
        try {
          var monitors = JSON.parse(text)
          for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i]
            var name = m.specialWorkspace ? m.specialWorkspace.name : ""
            if (name.indexOf(root.prefix) === 0) next[m.name] = name.slice(root.prefix.length)
            var reserved = m.reserved || [0, 0, 0, 0]
            origins[m.name] = { x: m.x + reserved[0], y: m.y + reserved[1] }
          }
        } catch (e) {
          return
        }
        root.shown = next
        root.origins = origins
        clientsQuery.running = true
      }
    }
  }

  Process {
    running: true
    command: [root.cli, "geometry"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.geometry = JSON.parse(text) } catch (e) {}
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
    function menu(): void {
      root.menuMonitor = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
      root.menuRequest++
    }
    function shown(): string { return JSON.stringify(root.shown) }
  }
}
