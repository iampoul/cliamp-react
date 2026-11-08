# cliamp-react

Music-reactive **window borders** and **Omarchy bar** for [Omarchy](https://omarchy.org/) + [cliamp](https://github.com/bjarneo/cliamp).

When cliamp plays, the gradient borders of every tiled window come alive: colours pulse with the
spectrum and the bright stop travels around all four edges. At the same time a compact spectrum
appears in the Omarchy bar and a full-width gradient/spectrum washes across the bar's background.
When the music stops, everything fades back to your theme's own colours. No audio capture, no new
packages.

```
cliamp (TUI or --daemon)
  ├─ IPC socket ~/.config/cliamp/cliamp.sock
  │    └─ spectrum.get (30 fps) + state.get
  │         └─ cliamp-react (Python 3 stdlib, systemd user service)
  │              └─ Hyprland IPC: eval hl.config({ ... active_border / inactive_border ... })
  └─ cliamp visstream --fps 30 (NDJSON)
       └─ io.github.iampoul.cliamp-react (Omarchy shell plugin, QML)
            ├─ BarWidget.qml    — compact spectrum inside the bar
            └─ BarBackground.qml — reactive backdrop behind the bar
```

Both halves ship in this repo, share one `config.toml`, and work independently: stopping the
Python service leaves the bar alone, disabling the bar plugin leaves the borders alone.

## Features

- **All windows react** — both the focused (`active_border`) and unfocused (`inactive_border`)
  borders get the same moving gradient, not just the active window.
- **Bar visualizer** — a 24-band spectrum in the top bar and a mirrored full-width spectrum behind
  it, with a theme-accent → theme-red gradient that breathes with loudness and kicks on beats.
- **Two border motion modes** — `all` spins the gradient around the whole frame (faster when
  louder), `bottom` keeps the bright stop on the lower edges.
- **Theme-aware** — colours come from the active Omarchy theme and follow theme changes.
- **Clean exit** — ~0.5 s fade back to the theme's exact own border and bar colour on
  pause/stop/quit. Nothing is hardcoded per theme.
- **No dependencies** beyond Python 3.11+ (for `tomllib`), systemd, Hyprland, Omarchy and cliamp.

## Requirements

- Omarchy with Hyprland 0.56+ (the Lua-based config — see note below)
- Omarchy shell with plugin support (`omarchy plugin` command)
- [cliamp](https://github.com/bjarneo/cliamp) 2.4+ running, either its TUI or `cliamp --daemon`
  (the IPC socket `~/.config/cliamp/cliamp.sock` must exist)
- Python 3.11+
- A systemd user session (`graphical-session.target`)

## Install

```sh
git clone https://github.com/iampoul/cliamp-react
cd cliamp-react
./install.sh
```

`install.sh` copies the scripts to `~/.local/bin`, the config to `~/.config/cliamp-react/config.toml`
(only if you don't already have one), the systemd unit to `~/.config/systemd/user/`, installs the
theme hook, and enables + starts the service. It also installs and enables the Omarchy bar plugin,
sets the bar background to `glassy` so the reactive backdrop shows through, and restarts the
Omarchy shell. The previous bar background is saved in
`~/.config/cliamp-react/previous-bar-background` so it can be restored.

Flags:

```sh
./install.sh --no-bar       # borders only, skip the bar plugin and background change
./install.sh --no-restart   # install everything but don't restart the shell
```

Manual install (borders only):

```sh
install -Dm755 cliamp-react ~/.local/bin/cliamp-react
install -Dm755 cliamp-react-ctl ~/.local/bin/cliamp-react-ctl
install -Dm755 cliamp-react-palette ~/.local/bin/cliamp-react-palette
install -Dm644 config.toml.example ~/.config/cliamp-react/config.toml
install -Dm644 cliamp-react.service ~/.config/systemd/user/cliamp-react.service
install -Dm755 cliamp-react-palette ~/.config/omarchy/hooks/theme-set.d/cliamp-react-palette
systemctl --user daemon-reload
systemctl --user enable --now cliamp-react.service
```

Manual install (bar plugin):

```sh
id=io.github.iampoul.cliamp-react
mkdir -p ~/.config/omarchy/plugins/$id
cp bar/* ~/.config/omarchy/plugins/$id/
omarchy plugin validate ~/.config/omarchy/plugins/$id
omarchy shell shell rescanPlugins
omarchy plugin enable $id --section centerBegin
omarchy bar background glassy
omarchy restart shell
```

## Use

Start cliamp (TUI or `cliamp --daemon --auto-play`) and play something. Control it with:

```sh
cliamp-react-ctl status       # service state
cliamp-react-ctl restart      # pick up border config changes
cliamp-react-ctl reload       # re-read config + theme palette (SIGUSR1)
cliamp-react-ctl log          # last 40 journal lines
cliamp-react-ctl stop         # restores the theme border before exiting
cliamp-react-ctl bar on       # enable the bar plugin + glassy background
cliamp-react-ctl bar off      # disable it and restore the previous bar look
cliamp-react-ctl bar status   # plugin + background + service state
```

Left-clicking the spectrum widget toggles cliamp play/pause. The bar half reads `config.toml`
live — no restart needed after editing `[bar]`.

## Configuration

`~/.config/cliamp-react/config.toml`. Border changes need `cliamp-react-ctl restart`; bar changes
are picked up automatically.

| Option | Default | Meaning |
| --- | --- | --- |
| `source.fps` | `30` | Spectrum polls per second (1–60). |
| `border.enabled` | `true` | Master switch. |
| `border.fps` | `20` | Border updates per second. Every change repaints windows. |
| `border.mode` | `"all"` | `"all"` = gradient travels all four edges; `"bottom"` = bright stop stays on bottom edges. |
| `border.spin` | `0.20` | `all` mode: extra turns/second at full loudness. |
| `border.angle` | `120` | `bottom` mode: gradient angle for the bottom edge. |
| `border.sweep` | `30` | `bottom` mode swing in degrees; also the `all` mode beat kick. |
| `border.min_alpha` | `200` | Darkest first gradient stop (0–255). |
| `border.idle_after` | `0.9` | Seconds after playback stops before the fade begins. |
| `border.fade_ms` | `500` | Fade duration back to the theme border. |
| `bar.enabled` | `true` | Master switch for the bar half. |
| `bar.background` | `true` | Full-width reactive backdrop behind the bar. |
| `bar.fps` | `24` | Widget repaint rate while playing (idle costs nothing). |
| `bar.background_fps` | `12` | Backdrop repaint rate; it sits behind a blur, so 12 is plenty. |
| `bar.cols` | auto | Optional: override the number of columns in the backdrop. |
| `bar.bars` | `24` | Bands drawn in the compact widget. |
| `bar.width` | `150` | Widget width in px. |
| `bar.gain` | `1.0` | Spectrum amplitude multiplier (0.2–2.0). |
| `bar.fade_ms` | `400` | Fade in/out on play and pause. |
| `bar.click` | `"toggle"` | Left-click action: `"toggle"` / `"none"`. |
| `debug.log_level` | `"info"` | `debug` / `info` / `warn` / `error`. |

Try slower border motion: `spin = 0.08`. Prefer the under-window glow: `mode = "bottom"`.
A stronger bar: `bar.gain = 1.5` or `omarchy bar background none` (our panel then becomes the
entire bar background).

## How it works

cliamp exposes newline-delimited JSON V2 IPC. The Python daemon sends
`{"version":2,"id":"...","method":"spectrum.get"}` at 30 fps (normalized 10-band spectrum) and
`state.get` twice a second for exact play/pause detection.

Hyprland 0.56 runs a Lua config, so **`hyprctl keyword general:col.active_border …` does not
work** ("keyword can't work with non-legacy parsers"). Instead the daemon writes directly to
`$XDG_RUNTIME_DIR/hypr/<signature>/.socket.sock`:

```
eval hl.config({ general = { col = { active_border = {...}, inactive_border = {...} } } })
```

~0.1 ms per command over the raw socket. On fade-out it re-applies the active theme's own
`~/.local/state/omarchy/current/theme/hyprland.lua` with `eval dofile(...)`, which is exact for
every theme.

The bar half is an Omarchy shell plugin (`kinds: service, bar-widget`). Its service spawns
`cliamp visstream --fps 30`, computes an envelope and beat in JS, and polls `cliamp status --json`
once a second for exact play/pause state. Theme colours come from the shell's own
`Commons.Color` singleton, so they follow `omarchy theme set`. The backdrop is a `PanelWindow` on
the **Bottom** layer with `ExclusionMode.Ignore` and an empty input mask — no reserved space, no
clicks stolen. It sits behind the bar, which is set to `glassy` so Omarchy's own blur turns the
spectrum into an ambient wash. When paused the reactive canvas fades to zero over the theme's own
bar colour, so the bar looks exactly as it did before.

## Limitations

- Hyprland border colours are **global**: all windows share the gradient, and there is no
  per-edge control. `mode = "bottom"` approximates an underglow — the whole 2 px frame still
  carries the gradient.
- The bar background needs `omarchy bar background glassy` (or `none`). With `opaque` the
  backdrop is hidden; use `cliamp-react-ctl bar off` to restore the previous look.
- The backdrop lives on the Bottom layer, so a floating window dragged into the bar strip would
  cover it. Tiled windows never do.
- Requires cliamp to be running. While it is stopped the daemon sits idle at ~0 CPU and the bar
  canvases stop repainting.
- Built for Omarchy/Hyprland's Lua config; it will not work on a classic `hyprland.conf` setup
  without adapting the `hl.config` calls.

## Troubleshooting

```sh
cliamp status                                  # is cliamp running / playing?
cliamp visstream --fps 5                       # does the spectrum stream produce bands?
journalctl --user -u cliamp-react -f           # daemon logs
journalctl --user -u wayland-wm@hyprland.desktop.service --since "5 min ago" | grep -i cliamp
hyprctl getoption general:col.active_border    # currently applied gradient
hyprctl layers | grep -A5 "bottom"             # cliamp-react-bar backdrop present?
omarchy plugin list | grep cliamp-react        # plugin discovered/enabled?
hyprctl configerrors                           # any Hyprland config errors?
```

`omarchy theme set` reloads Hyprland config and briefly resets the borders; the daemon
reapplies on its next frame while music plays. The `theme-set` hook reloads the palette.

## Uninstall

```sh
cliamp-react-ctl bar off
systemctl --user disable --now cliamp-react.service
rm ~/.local/bin/cliamp-react ~/.local/bin/cliamp-react-ctl ~/.local/bin/cliamp-react-palette
rm ~/.config/systemd/user/cliamp-react.service
rm ~/.config/omarchy/hooks/theme-set.d/cliamp-react-palette
rm -r ~/.config/cliamp-react ~/.config/omarchy/plugins/io.github.iampoul.cliamp-react
hyprctl eval 'dofile(os.getenv("HOME") .. "/.local/state/omarchy/current/theme/hyprland.lua")'
```
