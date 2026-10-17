# A group is a special workspace with the scrolling layout

**Status:** accepted 2026-10-17

## Context
The user wants several open windows inside one window, with scroll and resize like a workspace. A Hyprland group (`togglegroup`) shows one member at a time, as tabs. Hyprland cannot put a tiled layout inside one client window.

## Decision
Each group is the special workspace `special:omagroup-<id>` with `layout = "scrolling"` and wide `gaps_out`. The shell draws a frame (header with a menu) in the top gap. Minimize hides the special workspace.

## Consequences
- Scroll, resize, focus and fullscreen are native Hyprland behaviour. omagroup adds no layout code.
- A shown group dims the workspace below it (`dim_special`), and only one special workspace shows on a monitor at a time.
- `hide_special_on_workspace_change` hides a group when the user changes workspace. That counts as minimize.
- Rejected: a Hyprland group, because it has no scroll or resize between members.
- Rejected: a nested compositor in a window, because Wayland cannot move a running window into another compositor.
- Rejected: a Hyprland C++ plugin with a custom layout, because it breaks on each Hyprland release and duplicates the scrolling layout.
