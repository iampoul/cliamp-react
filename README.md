# cliamp-react

Music-reactive **window borders** for [Omarchy](https://omarchy.org/) + [cliamp](https://github.com/bjarneo/cliamp).

When cliamp plays, the gradient borders of every tiled window come alive: colours pulse with the
spectrum, the bright stop travels around all four edges (or stays on the bottom edges), and the
whole frame fades back to your theme's own border when the music stops. No separate visualizer
window, no overlay, no audio capture — just the borders of the apps you already have open.

```
cliamp (TUI or --daemon)
  └─ IPC socket ~/.config/cliamp/cliamp.sock
       └─ spectrum.get (30 fps) + state.get
            └─ cliamp-react (Python 3 stdlib)
                 └─ Hyprland IPC: eval hl.config({ ... col.active_border / col.inactive_border ... })
```

## Features

- **All windows react** — both the focused (`active_border`) and unfocused (`inactive_border`)
  borders get the same moving gradient, not just the active window.
- **Two motion modes** — `all` spins the gradient around the whole frame (faster when louder),
  `bottom` keeps the bright stop on the lower edges and slides it left/right.
- **Beat response** — fast-attack/slow-release envelope, bass beat detector, colour and alpha
  oscillation, angle kick on beats.
- **Theme-aware** — accent colours come from the active Omarchy theme's `colors.toml`; changing
  themes reloads them automatically via a `theme-set` hook.
- **Clean exit** — ~0.5 s fade back to the theme's exact own border on pause/stop/quit, using the
  theme's generated `hyprland.lua` (nothing is hardcoded per theme).
- **No dependencies** beyond Python 3.11+ (for `tomllib`), systemd, Hyprland and cliamp.

## Requirements

- Omarchy with Hyprland 0.56+ (the Lua-based config — see note below)
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
theme hook, enables + starts the service, and — on an Omarchy machine — installs the bar control
plugin to `~/.config/omarchy/plugins/io.github.iampoul.cliamp-react/` and adds it to the right
section of the bar.

Manual install:

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

## Use

Start cliamp (TUI or `cliamp --daemon --auto-play`) and play something. Control the service with:

```sh
cliamp-react-ctl status     # service state
cliamp-react-ctl restart    # pick up config changes
cliamp-react-ctl reload     # re-read config + theme palette (SIGUSR1)
cliamp-react-ctl log        # last 40 journal lines
cliamp-react-ctl stop       # restores the theme border before exiting
```

### Bar control

On Omarchy the installer adds a music-note pill to the bar's right section. The pill shows a small
state dot: accent while the effect is live, dimmed when it is off, darker still while the service is
stopped.

- **Click** — open the control panel.
- **Shift+click** — toggle the effect on/off.
- **Middle-click** — cycle the motion path (`all` ↔ `bottom`).

The panel has the master toggle, the motion path, the `Calm` / `Balanced` / `Wild` presets and a
**Reset** that drops every override. Presets only touch the motion knobs and leave the mode alone:

| Preset | `spin` | `sweep` | `min_alpha` | `fps` |
| --- | --- | --- | --- | --- |
| `Calm` | 0.08 | 15° | 150 | 15 |
| `Balanced` | 0.20 | 30° | 200 | 20 |
| `Wild` | 0.45 | 45° | 235 | 30 |

Every change is applied live: the ctl writes `overrides.toml` and sends the daemon `SIGUSR1`, so no
restart and no `config.toml` rewrite. The same actions are available from a shell:

```sh
cliamp-react-ctl get                    # effective settings as JSON
cliamp-react-ctl set enabled false      # true/false
cliamp-react-ctl set mode bottom        # all/bottom
cliamp-react-ctl set spin 0.3           # fps 1-60, spin 0-2, sweep 0-90, min_alpha 0-255
cliamp-react-ctl preset calm            # calm/balanced/wild
cliamp-react-ctl reset                  # back to config.toml
```

## Configuration

`~/.config/cliamp-react/config.toml` (restart after editing):

| Option | Default | Meaning |
| --- | --- | --- |
| `source.fps` | `30` | Spectrum polls per second (1–60). |
| `border.enabled` | `true` | Master switch. |
| `border.fps` | `20` | Border updates per second. Every change repaints windows, so lower is cheaper. |
| `border.mode` | `"all"` | `"all"` = gradient travels all four edges; `"bottom"` = bright stop stays on bottom edges. |
| `border.spin` | `0.20` | `all` mode: extra turns/second at full loudness (slower when quiet). |
| `border.angle` | `120` | `bottom` mode: gradient angle that puts the bright stop on the bottom edge. |
| `border.sweep` | `30` | `bottom` mode swing in degrees; also the `all` mode beat kick. |
| `border.min_alpha` | `200` | Darkest first gradient stop (0–255). |
| `border.idle_after` | `0.9` | Seconds after playback stops before the fade begins. |
| `border.fade_ms` | `500` | Fade duration back to the theme border. |
| `debug.log_level` | `"info"` | `debug` / `info` / `warn` / `error`. |

Try slower motion: `spin = 0.08`. Prefer the under-window glow: `mode = "bottom"`.
Bolder colours: raise `min_alpha` or edit `Palette` to use a different theme colour.

### Overrides

The bar panel and `cliamp-react-ctl` never rewrite `config.toml` — comments stay intact. They
write `~/.config/cliamp-react/overrides.toml` instead, which is layered on top:

```
defaults ← config.toml ← overrides.toml
```

Delete `overrides.toml` (or press **Reset**) to fall back to `config.toml`. Overrides are read at
startup and on every `SIGUSR1` / service restart, so they survive reboots and theme changes.

## How it works

cliamp exposes newline-delimited JSON V2 IPC on its Unix socket. The daemon sends
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

## Limitations

- Hyprland border colours are **global**: all windows share the gradient, and there is no
  per-edge control. `mode = "bottom"` approximates an underglow by putting the bright gradient
  stop on the lower edges — the whole 2 px frame still carries the gradient.
- Only the borders change; no shadows, glows or extra surfaces are drawn.
- Requires cliamp to be running. While it is stopped the service sits idle at ~0 CPU.
- Built for Omarchy/Hyprland's Lua config; it will not work on a classic `hyprland.conf` setup
  without adapting the `hl.config` calls.

## Troubleshooting

```sh
cliamp status                                  # is cliamp running / playing?
cliamp visstream --fps 5                       # does the spectrum stream produce bands?
journalctl --user -u cliamp-react -f           # daemon logs
hyprctl getoption general:col.active_border    # currently applied gradient
hyprctl configerrors                           # any Hyprland config errors?
```

`omarchy theme set` reloads Hyprland config and briefly resets the borders; the daemon
reapplies on its next frame while music plays. The `theme-set` hook reloads the palette.

## Uninstall

```sh
systemctl --user disable --now cliamp-react.service
rm ~/.local/bin/cliamp-react ~/.local/bin/cliamp-react-ctl ~/.local/bin/cliamp-react-palette
rm ~/.config/systemd/user/cliamp-react.service
rm ~/.config/omarchy/hooks/theme-set.d/cliamp-react-palette
rm -r ~/.config/cliamp-react
```

Then remove the bar pill:

```sh
omarchy plugin disable io.github.iampoul.cliamp-react
rm -r ~/.config/omarchy/plugins/io.github.iampoul.cliamp-react
hyprctl eval 'dofile(os.getenv("HOME") .. "/.local/state/omarchy/current/theme/hyprland.lua")'
```
