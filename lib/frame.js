.pragma library

// Panel geometry for Frame.qml. Rects are { x, y, width, height } in the
// frame surface's coordinates: the work area of one monitor, in logical px.

function insetsOf(group, fallback) {
  var i = (group && group.insets) || {}
  function pick(v) { return typeof v === "number" ? v : fallback }
  return { top: pick(i.top), right: pick(i.right), bottom: pick(i.bottom), left: pick(i.left) }
}

function panelRect(size, insets) {
  return {
    x: insets.left,
    y: insets.top,
    width: Math.max(0, size.width - insets.left - insets.right),
    height: Math.max(0, size.height - insets.top - insets.bottom)
  }
}

function innerRect(panel, geometry) {
  return {
    x: panel.x + geometry.sidebar,
    y: panel.y + geometry.header,
    width: Math.max(0, panel.width - geometry.sidebar - geometry.pad),
    height: Math.max(0, panel.height - geometry.header - geometry.pad)
  }
}

function insetsFrom(rect, size) {
  return {
    top: Math.round(rect.y),
    right: Math.round(size.width - rect.x - rect.width),
    bottom: Math.round(size.height - rect.y - rect.height),
    left: Math.round(rect.x)
  }
}

// Members whose rectangle lies inside the inner area, within `tolerance`
// px. `origin` is the surface's top-left in global coordinates.
function holes(members, origin, inner, tolerance) {
  var list = []
  for (var i = 0; i < members.length; i++) {
    var m = members[i]
    if (!m.at || !m.size) continue
    var x = m.at[0] - origin.x
    var y = m.at[1] - origin.y
    if (x < inner.x - tolerance || y < inner.y - tolerance) continue
    if (x + m.size[0] > inner.x + inner.width + tolerance) continue
    if (y + m.size[1] > inner.y + inner.height + tolerance) continue
    list.push({ address: m.address, x: x, y: y, width: m.size[0], height: m.size[1] })
  }
  return list
}

function tabOrder(members) {
  return members.slice().sort(function(a, b) {
    return (a.at[0] - b.at[0]) || (a.at[1] - b.at[1])
  })
}

// The rect after dragging `mode` ("move" or an edge: n, s, e, w, ne, nw,
// se, sw) by dx, dy. It stays on the surface and keeps the minimum size.
function preview(start, mode, dx, dy, size, minWidth, minHeight) {
  var left = start.x, top = start.y
  var right = start.x + start.width, bottom = start.y + start.height
  if (mode === "move") {
    var x = Math.max(0, Math.min(size.width - start.width, left + dx))
    var y = Math.max(0, Math.min(size.height - start.height, top + dy))
    return { x: x, y: y, width: start.width, height: start.height }
  }
  if (mode.indexOf("w") !== -1) left = Math.max(0, Math.min(right - minWidth, left + dx))
  if (mode.indexOf("e") !== -1) right = Math.min(size.width, Math.max(left + minWidth, right + dx))
  if (mode.indexOf("n") !== -1) top = Math.max(0, Math.min(bottom - minHeight, top + dy))
  if (mode.indexOf("s") !== -1) bottom = Math.min(size.height, Math.max(top + minHeight, bottom + dy))
  return { x: left, y: top, width: right - left, height: bottom - top }
}

// SVG path of a rounded rect followed by plain rect holes. With an odd-even
// fill, the holes cut through the panel.
function panelPath(rect, radius, cutouts) {
  var r = Math.max(0, Math.min(radius, rect.width / 2, rect.height / 2))
  var x = rect.x, y = rect.y, w = rect.width, h = rect.height
  var d = "M " + (x + r) + " " + y
    + " H " + (x + w - r) + " A " + r + " " + r + " 0 0 1 " + (x + w) + " " + (y + r)
    + " V " + (y + h - r) + " A " + r + " " + r + " 0 0 1 " + (x + w - r) + " " + (y + h)
    + " H " + (x + r) + " A " + r + " " + r + " 0 0 1 " + x + " " + (y + h - r)
    + " V " + (y + r) + " A " + r + " " + r + " 0 0 1 " + (x + r) + " " + y + " Z"
  for (var i = 0; i < cutouts.length; i++) {
    var c = cutouts[i]
    d += " M " + c.x + " " + c.y + " H " + (c.x + c.width) + " V " + (c.y + c.height) + " H " + c.x + " Z"
  }
  return d
}
