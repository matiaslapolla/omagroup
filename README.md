# omagroup

Put open windows from any workspace into one scrolling group that floats over
your workspace, like a single large window. Built for Omarchy (Hyprland 0.55+
with Lua config, Omarchy shell).

- A **gallery** shows a live preview of every open window, with its workspace,
  monitor and process. Click the windows you want, in order, and press Enter.
- The **group** is a Hyprland special workspace with the scrolling layout.
  Scroll, resize, focus and fullscreen are the native ones.
- A **panel** holds the group: an opaque frame with a small header, and a
  scrim over the rest of the screen. Columns that scroll past the edge stay
  hidden under it. A click on the scrim minimizes the group.
- The header has previous and next column, narrower and wider, and a `⋯`
  menu with **Minimize**, **Ungroup** and **Close all**. Each button has a
  tooltip. The wheel on the panel moves one column, and Shift with the
  wheel resizes the focused one.
- Drag the header to another monitor to move the group there.

Typical use: a terminal, the dev server logs and a browser on `localhost`,
side by side in one unit that you can hide and bring back.

## Install

```bash
git clone https://github.com/matiaslapolla/omagroup.git
cd omagroup
./install.sh
```

`install.sh` links the checkout into `~/.config/omarchy/plugins/` and enables
the plugin. It also links the CLI to `~/.local/bin/omagroup`.

With `omarchy plugin add`, the CLI is not linked, because the installer runs
no install hooks. Link it yourself:

```bash
omarchy plugin add https://github.com/matiaslapolla/omagroup.git --enable
ln -s ~/.config/omarchy/plugins/matiaslapolla.omagroup/bin/omagroup ~/.local/bin/omagroup
```

Requires `jq` and `hyprctl`, which Omarchy ships.

## Launcher

Add these rows to `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"omagroup": {"icon":"󰕰","label":"Group Windows","description":"Pick open windows into one scrolling group","aliases":["omagroup","group windows"],"action":"omagroup"},
"omagroup-show": {"icon":"󰖯","label":"Show Window Group","description":"Bring back a minimized omagroup","aliases":["omagroup show"],"when":"omagroup list | jq -e 'any(.[]; .shown == null)' >/dev/null","action":"omagroup show"},
```

Search "omagroup" in the Omarchy menu, or bind a key in
`~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + G", "Group windows", "omagroup")
```

## CLI

```
omagroup                       open the gallery
omagroup create [--name N] ADDR...
omagroup list                  groups with their members (JSON)
omagroup windows               every window with location and process (JSON)
omagroup show [ID]             show a group; no ID picks a hidden one
omagroup hide [ID]             minimize
omagroup ungroup [ID]          move the members to the active workspace
omagroup close [ID]            close the members; SIGTERM what stays open after 3 s
omagroup scroll ID +col|-col
omagroup resize ID +0.1|-0.1
omagroup move ID MONITOR       show the group on MONITOR (--cursor: the one under the pointer)
omagroup menu                  open the panel menu of the shown group
omagroup geometry              panel margin, pad and header size (JSON)
```

Without an ID, `hide`, `ungroup` and `close` act on the group shown on the
focused monitor.

## How it works

- Group `og1` is the workspace `special:omagroup-og1`. Its rule
  (`layout = "scrolling"`, `gaps_out` from `omagroup geometry`) lives in
  `~/.local/state/omarchy/workspace-layouts/omagroup-og1.lua`, which Omarchy
  loads on each config reload.
- Members draw opaque (`opaque`, `force_rgbx`), so a translucent terminal does
  not show the workspace below.
- Names live in `~/.local/state/omagroup/groups.json`. Members come from
  Hyprland, so a window that you move out by hand leaves the group. A group
  without members is deleted.
- Changing workspace hides a shown group
  (`binds:hide_special_on_workspace_change` in Omarchy). Bring it back with
  `omagroup show` or the launcher row.

See [docs/adr/0001](docs/adr/0001-group-is-a-scrolling-special-workspace.md)
for why a group is a special workspace and not a Hyprland tab group.

## Limits

- Where no column covers the inner area, the dimmed workspace shows through.
  Hyprland draws layer surfaces either below every window or above them, so
  nothing can sit between the workspace and the members.
- One shown group per monitor, because Hyprland shows one special workspace
  per monitor.
- Groups do not survive a logout. Window addresses change at each login.
- The gallery shows the app icon for windows that Hyprland does not render at
  that moment, such as windows on hidden workspaces.

## Development

```bash
make check     # omarchy plugin validate, qmllint, CLI tests with a fake hyprctl
```

Saved QML reloads in the running shell, but a new IPC function needs
`omarchy restart shell`: the old IPC handler keeps the target name.

## License

MIT
