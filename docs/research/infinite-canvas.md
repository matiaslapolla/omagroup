# Infinite canvas for omagroup: research

Date: 2026-10-17. Machine: Arch, Hyprland 0.56.2, two monitors at scale 1.25.

## Answer

Try Phantomat first. It is a Hyprland 0.56 plugin that already gives an infinite, pannable, zoomable canvas. It draws each window with a scale and translate transform in Hyprland's own render pass, so it adds no nested compositor. Its author uses it daily on Omarchy with Hyprland 0.56.2 and two monitors. The fallback is driftwm, nested as one window inside Hyprland.

## 1. Canvas compositors and window managers

| Project | Model | Activity | Arch | Nested in Hyprland |
| --- | --- | --- | --- | --- |
| Phantomat | Hyprland plugin, infinite 2D canvas, pan and zoom | Last push 2026-10-08, no releases, 222 stars | Build from source | Not needed |
| driftwm | Smithay compositor, infinite 2D canvas, pan and zoom | v0.19.0 on 2026-09-14, 1.8k stars | AUR `driftwm` 0.19.0 | Yes, auto-detected |
| Halley | Smithay compositor, per-monitor infinite canvas, zoom | Last push 2026-10-17, 183 stars | AUR `halley` 0.8.0 | Yes, `halley --winit` |
| hevel | neuswc, infinite plane, scroll only | Last commit 2026-05-07 | AUR `hevel-git` 0.0.1 | Not found |
| niri | 1D scrolling columns | v26.04 on 2026-04-25 | `extra/niri` | Yes |
| hyprscroller | Hyprland scrolling layout plugin | Archived | n/a | n/a |

Sources:

- Phantomat: [README](https://github.com/kaolti/phantomat). It is "a zoomable, infinite-canvas window manager for Hyprland". It needs "Hyprland 0.56 or newer with its Lua config". It "hooks deep into Hyprland internals, so a Hyprland update can break it". The author tested it on "Omarchy, Hyprland 0.56.2, NVIDIA, two monitors". It is a fork of [hyprland-scroll-overview](https://github.com/yayuuu/hyprland-scroll-overview). Activity data comes from the GitHub API.
- driftwm: [README](https://github.com/malbiruk/driftwm). It calls itself "experimental software, primarily built with AI". It "auto-detects whether it's running nested". [Issue #234](https://github.com/malbiruk/driftwm/issues/234) reports a nested (winit backend) bug, now closed. [AUR](https://aur.archlinux.org/packages/driftwm).
- Halley: [README](https://github.com/saltnpepper97/halley). It is built on "Smithay's GLES renderer, damage-aware" rendering. It says "Zoom tops out at native scale". [AUR](https://aur.archlinux.org/packages/halley).
- hevel: [repo](https://git.sr.ht/~dlm/hevel). It starts with `swc-launch` on neuswc. I found no nested backend. [AUR](https://aur.archlinux.org/packages/hevel-git).
- niri: [Key bindings](https://github.com/YaLTeR/niri/blob/main/docs/wiki/Configuration:-Key-Bindings.md). Its layout is a 1D strip of columns, so it is not a 2D canvas.
- [cpiber/hyprscroller](https://github.com/cpiber/hyprscroller) and [dawsers/hyprscroller](https://github.com/dawsers/hyprscroller) are archived on GitHub.
- PaperWM (GNOME) and Karousel (KDE) are scrolling extensions of other desktops. They cannot run as one window inside Hyprland without the full GNOME or KDE shell. This is inference.

### Nested caveats (driftwm, Halley, niri)

- **Shortcuts.** Hyprland grabs SUPER bindings first. niri therefore makes `Mod` equal to `Alt` in a winit window ([Key bindings](https://github.com/YaLTeR/niri/blob/main/docs/wiki/Configuration:-Key-Bindings.md), [`mod-key-nested`](https://github.com/YaLTeR/niri/blob/main/docs/wiki/Configuration:-Input.md)). driftwm uses `Mod` for zoom and launch, so expect the same conflict. The driftwm part is inference.
- **Clipboard.** The nested compositor has its own Wayland seat. The host clipboard and the nested clipboard are separate unless a tool such as [clipboard-sync](https://github.com/dnut/clipboard-sync/) joins them. This is inference. Mutter has the same open problem in [mutter#3392](https://gitlab.gnome.org/GNOME/mutter/-/issues/3392).
- **Portals.** niri says portals "require running niri as a session" ([Important software](https://github.com/YaLTeR/niri/blob/main/docs/wiki/Important-Software.md)). A nested instance is not a session, so file pickers and screencast stay on the host portal. This is inference.
- **Fractional scale.** The nested compositor renders into one host surface. Clean 1.25 output depends on the winit backend honouring the host scale. I found no source for driftwm or Halley. Test it.

## 2. Hyprland 0.56 without nesting

- **Phantomat.** It sets `canvas.auto_float` and `canvas.desktop_mode`. It has continuous zoom with `canvas.min_zoom` and `canvas.max_zoom`. It forwards input to transformed windows with `canvas.direct_input` ([README](https://github.com/kaolti/phantomat)). The source draws each window with `RMOD_TYPE_SCALE` and `RMOD_TYPE_TRANSLATE` and does not move the real window ([Window.cpp](https://github.com/kaolti/phantomat/blob/main/Window.cpp)). The canvas covers the whole desktop. It is not one window.
- **Float everything and move windows to pan.** Each pan step moves every window by IPC. A move changes only the compositor-side position, so clients do not redraw. The cost grows with window count, and each step is a round trip. This gives no zoom. This is inference.
- **Lua custom layout.** Hyprland 0.56 lets a Lua function place windows with `hl.layout.register(name, { recalculate, layout_msg? })` ([Custom layouts](https://wiki.hypr.land/Configuring/Layouts/Custom-Layouts/), [example](https://github.com/hyprwm/Hyprland/blob/main/example/layouts/manual.lua)). A layout could keep canvas coordinates and a pan offset. I did not check whether Hyprland clamps boxes to the monitor. It gives no zoom.
- **`cursor.zoom_factor`.** This option exists in the 0.56 stubs (`/usr/share/hypr/stubs/hl.meta.lua`). It magnifies the whole monitor around the cursor. Zoom applies per monitor and resets when the cursor leaves ([discussion #2234](https://github.com/hyprwm/Hyprland/discussions/2234)). It cannot zoom out, so it cannot show more canvas.
- **Official plugins.** [hyprland-plugins](https://github.com/hyprwm/hyprland-plugins) now holds only borders-plus-plus, csgo-vulkan-fix, hyprbars and hyprfocus. hyprexpo is no longer in that repo. Built-in layouts are dwindle, master, scrolling and monocle ([Layouts](https://wiki.hypr.land/Configuring/Layouts/)).
- **ABI.** hyprpm pins one plugin commit to each Hyprland commit ([hyprpm.toml](https://github.com/hyprwm/hyprland-plugins/blob/main/hyprpm.toml)). Phantomat must be rebuilt after each Hyprland update ([README](https://github.com/kaolti/phantomat)).

## 3. Performance

- **Nested compositor.** The nested compositor draws all client buffers into its own window buffer. Hyprland then draws that buffer again. Each frame therefore has one extra full-window composite pass and one extra window-sized buffer chain. Input adds one hop through the host. This is inference from the design of a winit backend.
- **Damage.** Halley states damage-aware rendering ([README](https://github.com/saltnpepper97/halley)). A small change in a nested window still damages the host surface. Hyprland then redraws that part of the monitor. This is inference.
- **Direct scanout.** Hyprland has `render.direct_scanout` (0.56 stubs). A nested window is one more layer, so a fullscreen app inside it cannot use direct scanout. This is inference.
- **Phantomat.** It adds no extra buffer copy, because windows are drawn transformed in Hyprland's pass ([Window.cpp](https://github.com/kaolti/phantomat/blob/main/Window.cpp)). Its pass element reports the whole monitor as its box and as opaque ([OverviewPassElement.cpp](https://github.com/kaolti/phantomat/blob/main/OverviewPassElement.cpp)). So it probably redraws the full monitor while the canvas view is active. This is inference. The `canvas.persistent` option chooses whether that renderer stays on at 100% zoom ([README](https://github.com/kaolti/phantomat)). The barrel lens and blur add shader cost. No project publishes benchmarks.
- **The first omagroup approach.** It polled `hyprctl clients` every 300 ms and painted a layer surface over windows. Both cost work on every frame or tick. Phantomat and driftwm remove both.

## 4. Recommendation

1. **Phantomat.** It fits best.
   - Pros: real windows, no copy, pan and zoom, input forwarded, tested on this exact setup.
   - Cons: whole desktop rather than one window, one maintainer, no releases, rebuild after each Hyprland update. Interaction with omarchy-shell and hyprbars is unknown.
2. **driftwm, nested.** It gives one real window with a canvas inside.
   - Pros: packaged in AUR, active releases, real zoom.
   - Cons: extra composite pass, SUPER conflict, separate clipboard, AI-written and experimental.
3. **Halley, nested.** It has the same trade-offs as driftwm. It is younger, and zoom stops at native scale.
4. **Lua custom layout in omagroup.** It is the smallest code, but it gives no zoom. Each pan step relayouts every window.

Do not use niri, hevel or hyprscroller. niri is 1D. hevel has no nested backend. hyprscroller is archived.

## Experiment (under 1 hour)

Goal: confirm or kill Phantomat on this machine.

1. Read `scripts/install.sh` and `scripts/uninstall.sh` in [Phantomat](https://github.com/kaolti/phantomat).
2. Install the build dependencies with `sudo pacman -S --needed base-devel git hyprland hyprgraphics pango lua`.
3. Run `scripts/install.sh`. It backs up the config first.
4. Set `debug.overlay = true` to show frame times.
5. Open three terminals, a browser on `localhost` and `journalctl -f` in a fourth terminal.
6. Pan and zoom for 10 minutes across both monitors.
7. Note the frame times, text sharpness at 1.25 and 100% zoom, typing in a zoomed window, and the omarchy-shell bar.
8. Run `scripts/uninstall.sh`.

Kill Phantomat if one of these is true:

- The frame time goes above the monitor refresh interval during a pan.
- Text is blurry at 100% zoom.
- omarchy-shell or hyprbars break.

If Phantomat fails, run `driftwm` nested from the AUR. Repeat steps 5 to 7 in 15 minutes. Also check copy and paste between the host and the nested window.
