import { test } from "node:test"
import assert from "node:assert/strict"
import { load, plain } from "./load.mjs"

const F = load("frame")
const geometry = { inset: 32, pad: 8, header: 40, sidebar: 200 }
const size = { width: 2000, height: 1000 }

test("panel and inner rects come from insets and geometry", () => {
  const panel = F.panelRect(size, { top: 10, right: 20, bottom: 30, left: 40 })
  assert.deepEqual(plain(panel), { x: 40, y: 10, width: 1940, height: 960 })
  assert.deepEqual(plain(F.innerRect(panel, geometry)), { x: 240, y: 50, width: 1732, height: 912 })
})

test("missing insets fall back to the default inset", () => {
  assert.deepEqual(plain(F.insetsOf({}, 32)), { top: 32, right: 32, bottom: 32, left: 32 })
  assert.deepEqual(plain(F.insetsOf({ insets: { top: 1, right: 2, bottom: 3, left: 4 } }, 32)), { top: 1, right: 2, bottom: 3, left: 4 })
})

test("holes keep only whole members, in surface coordinates", () => {
  const origin = { x: 100, y: 830 }
  const inner = { x: 240, y: 50, width: 1700, height: 900 }
  const members = [
    { address: "0xa", at: [340, 880], size: [800, 900] },   // local 240,50: whole
    { address: "0xb", at: [1150, 880], size: [800, 900] },  // local 1050..1850: whole
    { address: "0xc", at: [1960, 880], size: [800, 900] },  // past the right edge
    { address: "0xd", at: [-700, 880], size: [800, 900] },  // past the left edge
  ]
  const holes = F.holes(members, origin, inner, 2)
  assert.deepEqual(plain(holes).map((h) => h.address), ["0xa", "0xb"])
  assert.deepEqual(plain(holes[0]), { address: "0xa", x: 240, y: 50, width: 800, height: 900 })
})

test("a member 1 px over the edge still counts as whole", () => {
  const holes = F.holes([{ address: "0xa", at: [239, 49], size: [802, 902] }], { x: 0, y: 0 }, { x: 240, y: 50, width: 800, height: 900 }, 2)
  assert.equal(holes.length, 1)
})

test("tabs follow tape order: x, then y", () => {
  const order = F.tabOrder([
    { address: "0xc", at: [900, 10] },
    { address: "0xa", at: [100, 500] },
    { address: "0xb", at: [100, 10] },
  ])
  assert.deepEqual(plain(order).map((m) => m.address), ["0xb", "0xa", "0xc"])
})

test("a move preview shifts the rect and stays on the surface", () => {
  const start = { x: 100, y: 100, width: 800, height: 600 }
  assert.deepEqual(plain(F.preview(start, "move", 50, -30, size, 640, 400)), { x: 150, y: 70, width: 800, height: 600 })
  assert.deepEqual(plain(F.preview(start, "move", -500, 900, size, 640, 400)), { x: 0, y: 400, width: 800, height: 600 })
})

test("a corner preview resizes and keeps the minimum size", () => {
  const start = { x: 100, y: 100, width: 800, height: 600 }
  assert.deepEqual(plain(F.preview(start, "se", 100, 50, size, 640, 400)), { x: 100, y: 100, width: 900, height: 650 })
  assert.deepEqual(plain(F.preview(start, "nw", 50, 40, size, 640, 400)), { x: 150, y: 140, width: 750, height: 560 })
  assert.deepEqual(plain(F.preview(start, "w", 400, 0, size, 640, 400)), { x: 260, y: 100, width: 640, height: 600 })
  assert.deepEqual(plain(F.preview(start, "e", 5000, 0, size, 640, 400)), { x: 100, y: 100, width: 1900, height: 600 })
})

test("insets come back from a rect", () => {
  assert.deepEqual(plain(F.insetsFrom({ x: 40, y: 10, width: 1940, height: 960 }, size)), { top: 10, right: 20, bottom: 30, left: 40 })
})

test("svg paths: a rounded panel and plain holes", () => {
  const path = F.panelPath({ x: 0, y: 0, width: 100, height: 50 }, 10, [{ x: 20, y: 20, width: 10, height: 10 }])
  assert.match(path, /^M 10 0 /)
  assert.match(path, /M 20 20 H 30 V 30 H 20 Z$/)
})
