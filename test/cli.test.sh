#!/usr/bin/env bash
# CLI tests against test/fake-hyprctl. Run: bash test/cli.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/bin/omagroup"
failures=0
passes=0

setup() {
  T=$(mktemp -d)
  mkdir -p "$T/bin"
  ln -s "$ROOT/test/fake-hyprctl" "$T/bin/hyprctl"
  export PATH="$T/bin:$PATH"
  export FAKE_LOG="$T/log" FAKE_CLIENTS="$T/clients.json" FAKE_MONITORS="$T/monitors.json"
  export OMAGROUP_STATE_DIR="$T/state" OMAGROUP_RULES_DIR="$T/rules" OMAGROUP_CLOSE_WAIT=0
  : >"$FAKE_LOG"
  clients '[]'
  monitors ""
}

teardown() { rm -rf "$T"; }

# clients '[{"address":"0xa","workspace":"3"}...]' with short fields
clients() {
  jq '[.[] | {
    address, class: (.class // "foot"), title: (.title // "t"), pid: (.pid // 0), monitor: (.monitor // 1), mapped: true, floating: (.floating // false),
    workspace: { id: (if (.workspace | test("^[0-9]+$")) then (.workspace | tonumber) else -98 end), name: .workspace }
  }]' <<<"$1" >"$FAKE_CLIENTS"
}

# monitors "<special on focused DP-1>" ["<special on HDMI-A-1>"] [<active workspace id of DP-1>]
monitors() {
  jq -n --arg special "$1" --arg other "${2:-}" --argjson active "${3:-3}" '[
    { id: 1, name: "DP-1", focused: true, x: 0, y: 0, width: 3440, height: 1440, scale: 1.25, reserved: [0, 30, 0, 0], activeWorkspace: { id: $active, name: ($active | tostring) }, specialWorkspace: { id: 0, name: $special } },
    { id: 0, name: "HDMI-A-1", focused: false, x: 2752, y: 0, width: 2560, height: 1440, scale: 1.25, reserved: [0, 30, 0, 0], activeWorkspace: { id: 11, name: "11" }, specialWorkspace: { id: 0, name: $other } }
  ]' >"$FAKE_MONITORS"
}

dispatches() { grep -o 'hl\.dsp[^;]*' "$FAKE_LOG" | sed 's/ *$//'; }

pass() { passes=$((passes + 1)); }
fail() {
  failures=$((failures + 1))
  echo "FAIL $CURRENT: $*"
}

assert_eq() { [[ $1 == "$2" ]] && pass || fail "expected [$2], got [$1]"; }
assert_contains() { grep -qF -- "$2" <<<"$1" && pass || fail "expected to contain [$2] in [$1]"; }
assert_not_contains() { grep -qF -- "$2" <<<"$1" && fail "did not expect [$2] in [$1]" || pass; }

run_test() {
  CURRENT=$1
  setup
  "$1"
  teardown
}

test_create_rejects_invalid_address() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa 'bad;rm' 2>/dev/null
  assert_eq "$?" 1
  assert_eq "$(dispatches)" ""
  assert_eq "$(cat "$FAKE_LOG" | grep -c eval)" 0
}

test_create_rejects_unknown_window() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa 0xb 2>/dev/null
  assert_eq "$?" 1
  assert_eq "$(dispatches)" ""
}

test_create_moves_windows_and_shows_group() {
  clients '[{"address":"0xa","workspace":"3"},{"address":"0xb","workspace":"11"}]'
  local id
  id=$("$CLI" create --name dev 0xa 0xb)
  assert_eq "$id" og1
  local d
  d=$(dispatches)
  assert_contains "$d" 'hl.dsp.window.move({ workspace = "special:omagroup-og1", window = "address:0xa", follow = false })'
  assert_contains "$d" 'hl.dsp.window.move({ workspace = "special:omagroup-og1", window = "address:0xb", follow = false })'
  assert_contains "$d" 'hl.dsp.workspace.toggle_special("omagroup-og1")'
  assert_contains "$(cat "$FAKE_LOG")" 'eval hl.workspace_rule({ workspace = "special:omagroup-og1", layout = "scrolling"'
  assert_contains "$(cat "$T/rules/omagroup-og1.lua")" 'layout = "scrolling"'
  assert_contains "$(cat "$T/rules/omagroup.lua")" 'force_rgbx = true'
  assert_eq "$(jq -c '.groups[0] | {id, name}' "$T/state/groups.json")" '{"id":"og1","name":"dev"}'
}

test_create_takes_next_free_id_and_default_name() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  local id
  id=$("$CLI" create 0xa)
  assert_eq "$id" og2
  assert_eq "$(jq -r '.groups[1].name' "$T/state/groups.json")" "group 2"
}

test_create_strips_control_characters_from_name() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create --name $'a\nb\tc' 0xa >/dev/null
  assert_eq "$(jq -r '.groups[0].name' "$T/state/groups.json")" "abc"
}

test_hide_toggles_only_a_shown_group() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  : >"$FAKE_LOG"
  "$CLI" hide og1
  assert_eq "$(dispatches)" ""
  monitors special:omagroup-og1
  "$CLI" hide
  assert_eq "$(dispatches)" 'hl.dsp.workspace.toggle_special("omagroup-og1")'
}

test_hide_on_other_monitor_focuses_it_first() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  monitors "" special:omagroup-og1
  : >"$FAKE_LOG"
  "$CLI" hide og1
  assert_eq "$(dispatches)" $'hl.dsp.focus({ monitor = "HDMI-A-1" })\nhl.dsp.workspace.toggle_special("omagroup-og1")'
}

test_scroll_of_hidden_group_fails() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  : >"$FAKE_LOG"
  "$CLI" scroll og1 +col 2>/dev/null
  assert_eq "$?" 1
  assert_eq "$(dispatches)" ""
}

test_create_skips_ids_still_used_by_live_windows() {
  clients '[{"address":"0xa","workspace":"special:omagroup-og4"},{"address":"0xb","workspace":"3"}]'
  assert_eq "$("$CLI" create 0xb)" og5
}

test_close_keeps_a_process_shared_with_other_windows() {
  sleep 30 &
  local shared=$!
  clients "[{\"address\":\"0xa\",\"workspace\":\"3\",\"pid\":$shared}]"
  "$CLI" create 0xa >/dev/null
  clients "[{\"address\":\"0xa\",\"workspace\":\"special:omagroup-og1\",\"pid\":$shared},{\"address\":\"0xb\",\"workspace\":\"5\",\"pid\":$shared}]"
  local err
  err=$("$CLI" close og1 2>&1)
  assert_contains "$err" "left foot open"
  kill -0 "$shared" 2>/dev/null && pass || fail "shared process was killed"
  kill "$shared"
  wait "$shared" 2>/dev/null
}

test_ungroup_accepts_a_named_workspace() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  clients '[{"address":"0xa","workspace":"special:omagroup-og1"}]'
  monitors special:omagroup-og1 "" -1337
  : >"$FAKE_LOG"
  "$CLI" ungroup
  assert_eq "$(dispatches | tail -1)" 'hl.dsp.window.move({ workspace = "-1337", window = "address:0xa", follow = false })'
}

test_show_skips_toggle_when_already_shown() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  monitors special:omagroup-og1
  : >"$FAKE_LOG"
  "$CLI" show og1
  assert_eq "$(dispatches)" ""
}

test_show_without_id_picks_the_only_hidden_group() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  : >"$FAKE_LOG"
  "$CLI" show
  assert_eq "$(dispatches)" 'hl.dsp.workspace.toggle_special("omagroup-og1")'
}

test_ungroup_moves_members_to_active_workspace_and_deletes() {
  clients '[{"address":"0xa","workspace":"3"},{"address":"0xb","workspace":"3"}]'
  "$CLI" create 0xa 0xb >/dev/null
  clients '[{"address":"0xa","workspace":"special:omagroup-og1"},{"address":"0xb","workspace":"special:omagroup-og1"},{"address":"0xc","workspace":"5"}]'
  : >"$FAKE_LOG"
  monitors special:omagroup-og1
  "$CLI" ungroup og1
  local d
  d=$(dispatches)
  assert_eq "$(head -1 <<<"$d")" 'hl.dsp.workspace.toggle_special("omagroup-og1")'
  assert_contains "$d" 'hl.dsp.window.move({ workspace = "3", window = "address:0xa", follow = false })'
  assert_contains "$d" 'hl.dsp.window.move({ workspace = "3", window = "address:0xb", follow = false })'
  assert_not_contains "$d" '0xc'
  assert_eq "$(jq -c '.groups' "$T/state/groups.json")" '[]'
  [[ -e $T/rules/omagroup-og1.lua ]] && fail "rule file still exists" || pass
}

test_close_closes_members_and_ends_survivors() {
  sleep 30 &
  local survivor=$!
  clients "[{\"address\":\"0xa\",\"workspace\":\"3\",\"pid\":$survivor}]"
  "$CLI" create 0xa >/dev/null
  clients "[{\"address\":\"0xa\",\"workspace\":\"special:omagroup-og1\",\"pid\":$survivor}]"
  : >"$FAKE_LOG"
  "$CLI" close og1
  assert_eq "$(dispatches)" 'hl.dsp.window.close({ window = "address:0xa" })'
  wait "$survivor" 2>/dev/null
  assert_eq "$?" 143
  assert_eq "$(jq -c '.groups' "$T/state/groups.json")" '[]'
}

test_prune_deletes_only_empty_groups() {
  clients '[{"address":"0xa","workspace":"3"},{"address":"0xb","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  "$CLI" create 0xb >/dev/null
  clients '[{"address":"0xb","workspace":"special:omagroup-og2"}]'
  "$CLI" prune
  assert_eq "$(jq -c '[.groups[].id]' "$T/state/groups.json")" '["og2"]'
}

test_scroll_and_resize_validate_arguments() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  monitors special:omagroup-og1
  : >"$FAKE_LOG"
  "$CLI" scroll og1 '+col"); os.exit(' 2>/dev/null
  assert_eq "$?" 1
  "$CLI" resize og1 '1' 2>/dev/null
  assert_eq "$?" 1
  "$CLI" scroll og1 +col
  "$CLI" resize og1 -0.1
  assert_eq "$(dispatches)" $'hl.dsp.layout("focus r")\nhl.dsp.layout("colresize -0.1")'
}

test_windows_labels_locations() {
  clients '[{"address":"0xa","workspace":"3","monitor":1},{"address":"0xb","workspace":"special:minimized"}]'
  local out
  out=$("$CLI" windows)
  assert_eq "$(jq -r '.[0].location' <<<"$out")" "WS 3 · DP-1"
  assert_eq "$(jq -r '.[1].location' <<<"$out")" "minimized"
}

test_rule_gaps_follow_geometry() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  assert_eq "$("$CLI" geometry)" '{"inset":32,"pad":8,"header":40,"sidebar":200}'
  assert_contains "$(cat "$T/rules/omagroup-og1.lua")" 'gaps_out = { top = 72, right = 40, bottom = 40, left = 232 }'
}

test_frame_sets_insets_and_gaps() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  : >"$FAKE_LOG"
  "$CLI" frame og1 10 20 30 40
  assert_eq "$(jq -c '.groups[0].insets' "$T/state/groups.json")" '{"top":10,"right":20,"bottom":30,"left":40}'
  assert_contains "$(cat "$T/rules/omagroup-og1.lua")" 'gaps_out = { top = 50, right = 28, bottom = 38, left = 240 }'
  assert_contains "$(cat "$FAKE_LOG")" 'eval hl.workspace_rule({ workspace = "special:omagroup-og1", layout = "scrolling", gaps_out = { top = 50'
  "$CLI" frame og1 10 20 30 '-1' 2>/dev/null
  assert_eq "$?" 1
  "$CLI" frame og1 10 20 30 2>/dev/null
  assert_eq "$?" 1
}

test_columns_are_thirds_on_a_wide_monitor_and_full_on_a_narrow_one() {
  clients '[{"address":"0xa","workspace":"3"}]'
  monitors special:omagroup-og1
  "$CLI" create 0xa >/dev/null
  assert_contains "$(dispatches)" 'hl.dsp.layout("colresize all 0.333")'
  : >"$FAKE_LOG"
  "$CLI" frame og1 32 800 32 32
  assert_contains "$(dispatches)" 'hl.dsp.layout("colresize all 1.0")'
}

test_create_tiles_floating_windows_and_ungroup_floats_them_again() {
  clients '[{"address":"0xa","workspace":"3","floating":true},{"address":"0xb","workspace":"3"}]'
  "$CLI" create 0xa 0xb >/dev/null
  local d
  d=$(dispatches)
  assert_contains "$d" 'hl.dsp.window.float({ window = "address:0xa", action = "disable" })'
  assert_not_contains "$d" 'address:0xb", action'
  clients '[{"address":"0xa","workspace":"special:omagroup-og1"},{"address":"0xb","workspace":"special:omagroup-og1"}]'
  : >"$FAKE_LOG"
  "$CLI" ungroup og1
  d=$(dispatches)
  assert_contains "$d" 'hl.dsp.window.float({ window = "address:0xa", action = "enable" })'
  assert_not_contains "$d" 'address:0xb", action'
}

test_focus_centers_a_member_and_rejects_others() {
  clients '[{"address":"0xa","workspace":"3"},{"address":"0xc","workspace":"5"}]'
  "$CLI" create 0xa >/dev/null
  clients '[{"address":"0xa","workspace":"special:omagroup-og1"},{"address":"0xc","workspace":"5"}]'
  monitors special:omagroup-og1
  : >"$FAKE_LOG"
  "$CLI" focus og1 0xa
  assert_eq "$(dispatches)" $'hl.dsp.focus({ window = "address:0xa" })\nhl.dsp.layout("center")'
  "$CLI" focus og1 0xc 2>/dev/null
  assert_eq "$?" 1
}

test_move_shows_the_group_on_the_monitor_under_the_cursor() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  monitors special:omagroup-og1
  : >"$FAKE_LOG"
  FAKE_CURSOR="3000, 400" "$CLI" move og1 --cursor
  assert_eq "$(dispatches | head -2)" $'hl.dsp.focus({ monitor = "HDMI-A-1" })\nhl.dsp.workspace.toggle_special("omagroup-og1")'
}

test_move_resets_insets_that_do_not_fit_the_target() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  "$CLI" frame og1 32 32 32 1500
  monitors special:omagroup-og1
  FAKE_CURSOR="3000, 400" "$CLI" move og1 --cursor
  assert_eq "$(jq -c '.groups[0].insets' "$T/state/groups.json")" '{"top":32,"right":32,"bottom":32,"left":32}'
}

test_move_to_the_same_monitor_does_nothing() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  monitors special:omagroup-og1
  : >"$FAKE_LOG"
  FAKE_CURSOR="100, 100" "$CLI" move og1 --cursor
  assert_eq "$(dispatches)" ""
}

test_move_rejects_an_unknown_monitor() {
  clients '[{"address":"0xa","workspace":"3"}]'
  "$CLI" create 0xa >/dev/null
  : >"$FAKE_LOG"
  "$CLI" move og1 'DP-9"})' 2>/dev/null
  assert_eq "$?" 1
  assert_eq "$(dispatches)" ""
}

test_unknown_group_is_rejected() {
  "$CLI" hide og9 2>/dev/null
  assert_eq "$?" 1
  "$CLI" close 'og1;x' 2>/dev/null
  assert_eq "$?" 1
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do run_test "$t"; done
echo "$passes passed, $failures failed"
((failures == 0))
