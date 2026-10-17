# omagroup v1 — plan

Spec: [docs/specs/omagroup-v1.md](../specs/omagroup-v1.md).

The units run in order in one session. Each unit needs the live screen to verify, so parallel sessions would fight over it.

## U1 — Scaffold and CLI
- **Files:** `manifest.json`, `Makefile`, `install.sh`, `bin/omagroup`, `test/cli.test.sh`, `test/fake-hyprctl`
- **Steps:**
  1. Write the manifest (kind `service`) and the Makefile with `validate`, `lint` and `test`.
  2. Write the fake `hyprctl`. It logs each call and answers `clients -j` from a fixture.
  3. Write failing CLI tests for validation, `create`, `hide`, `ungroup`, `close` and `prune`.
  4. Write `bin/omagroup` until the tests pass.
- **Check:** `make test` passes. A live `omagroup create` with two test windows gives `tiledLayout` `scrolling`.

## U2 — Service and frame
- **Files:** `Service.qml`, `Frame.qml`
- **Steps:**
  1. Track the shown special workspace of each monitor from `activespecial` and an initial `hyprctl monitors -j`.
  2. Draw a frame per monitor while a group shows there.
  3. Add the wheel actions and the `⋯` menu with the confirm step for Close.
  4. Run `omagroup prune` on each `closewindow` and `movewindow` event.
- **Check:** A screenshot shows the frame above a group. Minimize, Ungroup and Close work from the menu.

## U3 — Gallery
- **Files:** `Gallery.qml`, `Card.qml`
- **Steps:**
  1. Add the IPC function `pick`. It loads `omagroup windows` and opens the gallery.
  2. Draw the cards with live captures, location and process.
  3. Add selection, the name field, Enter, Escape and the Group button.
- **Check:** A screenshot shows cards from two workspaces. Enter with 3 cards makes a group.

## U4 — Launcher, README, publish
- **Files:** `README.md`, `~/.config/omarchy/extensions/omarchy-menu.jsonc`
- **Steps:**
  1. Add the launcher row to the user menu file, after a backup.
  2. Write the README: install, CLI, menu row, limits.
  3. Run `code-review` and the gate, then fix the findings.
  4. Create the public repo `matiaslapolla/omagroup` and push `main`.
- **Check:** The launcher row opens the gallery. `omarchy plugin validate` passes on a fresh clone.
