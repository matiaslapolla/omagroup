# omagroup v1.2 — the group as a window

**Status:** approved 2026-10-17 · **Source:** user feedback on v1.1, 2026-10-17

## Problem
In v1.1 a click on the inner area, where no member covers it, reaches the windows behind the group. A column that is only partly inside the inner area still shows. The group has a fixed size, and the only navigation is previous and next. In desktop mode new windows float, so they ignore the group layout.

## Goal
- The frame paints the panel everywhere except over **whole members**. Empty parts of the inner area get the panel background and take the clicks.
- A member that is only partly inside the inner area is covered.
- The user drags the panel edges and corners to resize the group, and the header to move it on its monitor or to another monitor.
- A sidebar on the left of the panel has one vertical tab per member. A click on a tab focuses that member and centers its column.
- Members are tiled while they are in a group. Ungroup makes floating again the members that floated before.

## Non-goals
- Live window movement while dragging. The panel shows a preview, and the members move on release.
- Tabs that reorder members by drag.

## Terms
- **Whole member**: a member whose rectangle lies inside the inner area, with 2 px of tolerance.
- **Insets**: the distances from the work area edges to the panel, per group, in logical pixels.
- **Tab**: one row of the sidebar for one member.

## Design

### State and rule (bin/omagroup)
- Each group in `groups.json` gets `insets` (`top`, `right`, `bottom`, `left`, default 32 each) and `floated` (addresses that floated at create).
- Constants: `PAD` 8, `HEADER` 40, `SIDEBAR` 200. `omagroup geometry` prints them with the default inset.
- Rule gaps: top = inset + `HEADER`, right and bottom = inset + `PAD`, left = inset + `SIDEBAR`.
- `omagroup frame ID TOP RIGHT BOTTOM LEFT` sets the insets, rewrites the rule file and applies it with `hyprctl eval`. Hyprland lays out the workspace again at once.
- `create` disables float on each member and records the ones that floated. `ungroup` floats them again.
- Columns: after `create` and `frame`, the CLI sets all columns to 1/3 of the inner width when the inner area is 1800 px wide or more, and to full width when it is narrower. An odd count lets a centered column keep whole neighbours.
- `omagroup focus ID ADDR` focuses the member and centers its column (`hl.dsp.layout("center")`).

### Member rectangles (Service.qml)
- While a group shows, the Service reads `hyprctl clients -j` on each Hyprland event and every 300 ms. The view moves during scroll animations without events.
- The Service also keeps each monitor's position and reserved area, so a frame converts global positions to surface positions.

### Frame painting and input
- The scrim covers the work area outside the panel.
- The panel color covers the panel minus the holes of whole members.
- The input mask is the surface minus the same holes. While the menu is open or a drag runs, there are no holes.

### Sidebar
- A list of tabs from the top of the inner area, in tape order (member x position). Each tab has the app icon and the title, elided.
- The focused member's tab has the accent background.
- The previous and next buttons stay in the header.

### Move and resize
- A drag on the header moves a preview of the panel. On release over another monitor, the frame runs `omagroup move`. On release over the same monitor, it runs `omagroup frame` with the new insets.
- An 8 px band on each panel edge and corner resizes the preview, with the matching cursor. The panel keeps at least 640 x 400 px. On release, the frame runs `omagroup frame`.
- A move to another monitor keeps the insets, clamped so the panel fits.

## Acceptance criteria
- [ ] `make check` passes. Tests cover the gaps from insets, `frame` validation, float restore on ungroup and the `focus` dispatches.
- [ ] With a real click (uinput test mouse) on an empty part of the inner area, the active window does not change to a window behind the group.
- [ ] A screenshot shows no partial column inside the panel.
- [ ] A test-mouse drag of the bottom-right corner makes the group smaller, and `hyprctl clients -j` shows smaller members.
- [ ] A test-mouse drag of the header moves the panel on the same monitor, and to the other monitor.
- [ ] A test-mouse click on a tab focuses that member, and its column is centered.
- [ ] In desktop mode, members are tiled in the group, and they float again after ungroup.
