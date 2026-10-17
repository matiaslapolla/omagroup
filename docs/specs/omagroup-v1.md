# omagroup v1

**Status:** approved 2026-10-17 · **Source:** conversation of 2026-10-17, [ADR 0001](../adr/0001-group-is-a-scrolling-special-workspace.md)

## Problem
The user develops web platforms. The user wants a terminal and a browser, or any other open windows, inside one movable unit. Hyprland groups show one window at a time, so the user cannot see the terminal and the site together.

## Goal
- The `omagroup` command opens a gallery from the terminal and from the Omarchy launcher.
- The user picks N windows from any workspace. omagroup puts them in a group.
- In a group, the user scrolls and resizes the members like on a scrolling workspace.
- A frame above the group has a menu with Minimize, Ungroup and Close.
- The repo is public, and `omarchy plugin add <url>` installs it.

## Non-goals
- Groups that survive a logout. Window addresses change at each login.
- More than one shown group on one monitor at a time.
- A dock or bar widget for hidden groups. harbor can show them in a later version.

## Terms
All terms are in [CONTEXT.md](../../CONTEXT.md).

## Design

### Parts
| Part | File | Job |
|---|---|---|
| CLI | `bin/omagroup` | All Hyprland and state changes. Bash and jq. |
| Service | `Service.qml` | Shell plugin of kind `service`. IPC target `omagroup`. Owns the gallery and the frames. |
| Gallery | `Gallery.qml` | Picker surface. |
| Frame | `Frame.qml` | Header of a shown group. |

The QML parts never call `hyprctl` to change state. They run the CLI. So the terminal and the shell do the same thing.

### CLI
```
omagroup                       open the gallery (omarchy-shell omagroup pick)
omagroup create [--name N] ADDR...
omagroup list                  JSON: groups with members
omagroup windows               JSON: every window, with location and process
omagroup show [ID]             show a group (no ID: pick a hidden group)
omagroup hide [ID]             minimize (no ID: the shown group of the focused monitor)
omagroup ungroup [ID]
omagroup close [ID]
omagroup prune                 delete groups without members
omagroup scroll ID +col|-col   move the scrolling view
omagroup resize ID +0.1|-0.1   resize the focused column
```
- The CLI validates each address (`0x` and hex) and each group id (`og` and digits). It rejects other input.
- `create` takes an id above every id in the state and on live workspaces. It writes the rule, moves the windows with `follow = false`, writes the state, then shows the group. The state comes last, so a prune during the moves cannot delete the group.
- `close` sends `hl.dsp.window.close` to each member. After 3 seconds, it sends SIGTERM to the process of each member that is still open. It skips a process that also owns windows outside the group, and prints a warning.
- `hide`, `scroll` and `resize` first focus the monitor that shows the group, because these dispatches act on the focused monitor. `scroll` and `resize` fail on a hidden group. `scroll` moves the focus one column (`focus r` or `focus l`), so a column always stays on screen.
- `ungroup` and `close` hide the group first. An emptied special workspace stays shown, and new windows would open inside it.
- When the shell runs the CLI, it sets `OMAGROUP_NOTIFY=1`. The CLI then shows each error as a notification.
- `ungroup` moves each member to the active regular workspace of the focused monitor.

### State
- Groups: `~/.local/state/omagroup/groups.json`, `{"groups":[{"id":"og1","name":"dev"}]}`.
- Rules: `~/.local/state/omarchy/workspace-layouts/omagroup-<id>.lua`. Omarchy loads this folder at each config reload, so the rule survives `hyprctl reload`. `create` also applies the rule at once with `hyprctl eval`.
- The rule sets `layout = "scrolling"` and `gaps_out` with a top gap that holds the frame.
- `omagroup.lua` in the same folder makes members opaque (`opaque`, `force_rgbx`). A translucent terminal would show the workspace below. The file stays after the last group goes.
- Members come from `hyprctl clients -j`, filtered by the workspace name.

### Gallery
- A full-screen layer surface on the focused monitor, with exclusive keyboard focus.
- One card per window on every workspace, minimized windows included. The card has a live capture (`ScreencopyView`), the location, the process name and the title.
- The location is `WS <n> · <monitor>`, `minimized` or `group <name>`.
- A click selects or clears a card. A top bar has a name field, the count and a Group button.
- Enter or the Group button runs `omagroup create`. Escape closes the gallery.
- The Group button stays off while no card is selected.

### Frame
- The Service tracks the shown special workspace of each monitor with the `activespecial` event.
- While a group shows on a monitor, a frame shows in the top gap of that monitor, as wide as the group.
- The frame has the group name, the member count, buttons for scroll left, scroll right, narrower and wider, and a `⋯` button.
- The mouse wheel on the frame runs `omagroup scroll`. Shift with the wheel runs `omagroup resize`.
- The `⋯` menu has Minimize, Ungroup and Close all. Close all asks for a second click on the same row within 3 seconds before it runs.

### Launcher and install
- `install.sh` links the repo into `~/.config/omarchy/plugins/matiaslapolla.omagroup`, links `bin/omagroup` into `~/.local/bin` and enables the plugin.
- The README gives two menu rows for `~/.config/omarchy/extensions/omarchy-menu.jsonc`. The first runs `omagroup` and has the aliases `omagroup` and `group windows`. The second runs `omagroup show` and shows only while a group is hidden.
- The IPC target `omagroup` has `pick`, `cancel` and `shown`.
- `omarchy plugin add` does not run install hooks. The README tells the user to link the CLI by hand after a plugin add.

## Acceptance criteria
- [ ] `make check` passes: `omarchy plugin validate .`, qmllint and the CLI tests.
- [ ] The CLI tests run with a fake `hyprctl` and check the dispatch strings of `create`, `hide`, `ungroup` and `close`.
- [ ] `omagroup create` with an invalid address exits with a non-zero code and dispatches nothing.
- [ ] `omagroup` in a terminal opens the gallery. The launcher row opens the same gallery.
- [ ] The gallery shows windows from at least two workspaces, each with its location and process name.
- [ ] Picking 3 windows and pressing Enter puts them on `special:omagroup-<id>`, and `hyprctl workspaces -j` reports `tiledLayout` `scrolling`.
- [ ] After `hyprctl reload`, the group workspace still reports `scrolling`.
- [ ] The frame shows above a shown group, and the wheel on the frame moves the view by one column.
- [ ] Minimize hides the group and its frame. `omagroup show` brings both back.
- [ ] Ungroup moves every member to the active workspace and removes the state entry and the rule file.
- [ ] Close closes every member and removes the state entry and the rule file.
- [ ] Closing the last member by hand deletes the group within 2 seconds.
- [ ] `matiaslapolla/omagroup` is public on GitHub, and `omarchy plugin validate` passes on a fresh clone.
