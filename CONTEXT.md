# omagroup — domain language

**Group**:
A named special workspace with the scrolling layout that holds windows the user picked. It shows over the active workspace with wide margins, so it looks like one large window.
_Avoid_: Hyprland group, tab group, container

**Group id**:
The short slug of a group, such as `og3`. The special workspace of the group is `special:omagroup-<id>`.

**Member**:
A window on the special workspace of a group. Membership comes from Hyprland, not from a stored list.

**Gallery**:
The full-screen picker that shows a live preview card for each open window on every workspace.

**Card**:
One item of the gallery: the window preview, its location (workspace and monitor) and its process.

**Frame**:
The header bar that the shell draws above a visible group. It has the group name and the menu button.

**Shown group / hidden group**:
A group is shown while its special workspace is visible on a monitor. A hidden group is a minimized group: it keeps its members and comes back with `omagroup show`.

**Ungroup**:
Move each member to the active workspace and delete the group.

**Close**:
Close each member, end the processes that stay alive, and delete the group.
