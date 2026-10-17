# omagroup v1.1 — contained frame

**Status:** approved 2026-10-17 · **Source:** user feedback on v1, 2026-10-17

## Problem
In v1 the group does not look contained. Columns of the scrolling tape overflow into the margins, the header is a loud separate pill, the icons do not say what they do, and the `⋯` button does not open the menu.

## Goal
- An opaque panel surrounds the members, so the group reads as one window with a background.
- Nothing of the group shows outside the panel's inner area.
- The header is part of the panel, small and muted.
- Each frame button has a tooltip and an icon that matches its action.
- `⋯` opens the menu.

## Non-goals
- A background behind the members inside the inner area. Hyprland draws layer surfaces either below all windows or above them, so the inner area keeps the dimmed workspace where no column covers it.

## Terms
- **Panel**: the opaque rounded rectangle that holds the header and the members.
- **Inner area**: the part of the panel where the members show. The frame leaves it transparent and click-through.
- **Scrim**: the dark cover over the rest of the monitor.

## Design

### Geometry
- `bin/omagroup` owns three values: `MARGIN` (32), `PAD` (8) and `HEADER` (40). `omagroup geometry` prints them as JSON.
- The workspace rule sets `gaps_out` to `MARGIN + HEADER` on top and `MARGIN + PAD` on the other sides.
- The Service reads `omagroup geometry` once. Frame draws the panel at `MARGIN` from the work area and the inner area at the rule's gaps.

### Frame surface
- One layer surface per monitor, on the Top layer, that covers the work area. Top layer surfaces draw above the special workspace, so the panel and the scrim cover overflowing columns.
- The panel is a ring: a rounded rectangle minus the inner area (Shape with odd-even fill). Its color is the popup background at full opacity.
- The scrim covers the work area outside the panel at 75 % opacity. A click on the scrim minimizes the group.
- The input mask is the surface minus the inner area, so clicks and the keyboard reach the members. While the menu is open, the mask covers the whole surface.
- The mouse wheel anywhere on the panel scrolls, and Shift with the wheel resizes.

### Header
- Inside the panel's top `HEADER` pixels: icon, name and member count in caption size, at 70 % text opacity.
- Buttons are 26 px, with no background until hover:

| Action | Icon | Tooltip |
|---|---|---|
| Previous column | `md-chevron_left` | Previous column |
| Next column | `md-chevron_right` | Next column |
| Narrower | `md-arrow_collapse_horizontal` | Narrower column |
| Wider | `md-arrow_expand_horizontal` | Wider column |
| Menu | `md-dots_horizontal` | Group menu |

- Tooltips use the shell's `PanelToolTip`.

### Menu
- The menu anchors to the right edge of the panel, under the header. Anchors keep it in place when the surface resizes.
- Rows: Minimize (`md-window_minimize`), Ungroup (`md-ungroup`), Close all (`md-close_box_multiple`).
- `omagroup menu` opens the menu of the group on the focused monitor, through the IPC function `menu`.

## Acceptance criteria
- [ ] `make check` passes, and a test checks the gaps that the rule gets from `MARGIN`, `PAD` and `HEADER`.
- [ ] `omagroup geometry` prints `{"margin":32,"pad":8,"header":40}`.
- [ ] A screenshot of a shown group with 3 columns shows the panel around the members and no column outside the inner area.
- [ ] `omagroup menu` opens the menu, and a screenshot shows it under `⋯`.
- [ ] Each frame button shows its tooltip on hover.
- [ ] A click in the inner area reaches the member under the pointer.
