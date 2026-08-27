# Matrix Rain

A live, theme-coloured matrix rain wallpaper for [Omarchy](https://omarchy.org/)
— drawn natively in QML, not played back from a video file, so it recolours
itself the moment you switch themes. The same plugin also plays looping video
and animated GIF/WebP wallpapers.

![Theme-coloured katakana falling as a live wallpaper](docs/demo.webp)

Whole desktop, same thing running behind the bar:

![Matrix rain as the desktop wallpaper](docs/screenshot.png)

It does **not** replace `omarchy.background`. The stock plugin keeps drawing
your still wallpapers and keeps every upstream fix; this one claims the *bottom*
layer — above the wallpaper, below every window and the bar — and maps itself
only while the selected background is something a still image cannot draw.
Select a normal wallpaper and the surface is not mapped at all, so your desktop
is bit-for-bit stock and this plugin costs nothing.

## Install

```bash
omarchy plugin add https://github.com/nzkritik/omarchy-matrix-rain --enable --yes
```

Then turn the rain on:

```bash
omarchy-shell matrix-rain select
```

## Requirements

- Omarchy 4 with `omarchy-shell`
- ImageMagick — generates the picker entry
- `qt6-multimedia` + `qt6-multimedia-ffmpeg`, for video wallpapers only

All ship with Omarchy. `inotifywait` is used when present; without it the plugin
falls back to a one-second poll.

## Use

The rain appears as an entry in your normal background picker — double-click an
empty part of the desktop, or Menu → Style → Background — under **every** theme,
and it takes the theme's accent colour.

```bash
omarchy-shell matrix-rain select           # the rain
omarchy-shell matrix-rain status           # what is playing, and from where
omarchy theme bg set ~/Videos/loop.mp4     # looping video
omarchy theme bg set ~/Pictures/loop.gif   # animated GIF or WebP
```

Animated GIF and WebP also show up in the picker on their own, because Omarchy
already lists those extensions; their thumbnail is the first frame. Video is
CLI-only, since the picker filters to still-image extensions.

### Tuning the rain

Every knob is a `readonly property` at the top of `MatrixRain.qml` — glyph grid
pitch, fall speed range, trail lengths, how often glyphs mutate, and the
alphabet itself. Edit and run `omarchy restart shell`.

| Property | Default | What it does |
| --- | --- | --- |
| `cell` | 16 | Glyph grid pitch in px. Smaller is denser |
| `minSpeed` / `maxSpeed` | 2.5 / 8.0 | Fall speed range, in grid rows per second |
| `minTrail` / `maxTrail` | 14 / 48 | Glyphs per falling stream |
| `churnInterval` | 90 | ms between glyph mutations |
| `alphabet` | katakana + digits | The glyph set |

After changing the look, refresh the picker thumbnail so it matches: select the
rain, clear the screen or switch to an empty workspace, and run

```bash
~/.config/omarchy/plugins/nzkritik.matrix-rain/bin/omarchy-matrix-preview --capture
```

## How the rain gets into the picker

Omarchy's picker can only list still images, so the rain is represented by a
preview PNG named `zz-matrix-rain.png`, written into the **current theme's**
user background folder — a directory the stock picker already scans. Selecting
it symlinks that path like any wallpaper, and the plugin recognises the name and
draws the live effect instead of the still.

Nothing overrides a packaged command and there is no hook to install: the plugin
watches `~/.local/state/omarchy/current/theme.name` and re-tints the preview
itself when the theme changes. Files are created lazily, so only themes you
actually use get one.

Two consequences: `omarchy theme bg next` cycles through the rain along with
that theme's other backgrounds, and uninstalling leaves the preview files
behind — see below.

## Uninstall

```bash
omarchy plugin remove nzkritik.matrix-rain --yes
find ~/.config/omarchy/backgrounds -name zz-matrix-rain.png -delete
rm -rf ~/.local/state/omarchy-matrix-rain
```

## How it works

| File | Role |
| --- | --- |
| `Service.qml` | The bottom-layer overlay, the background watcher, preview upkeep, and the `matrix-rain` IPC target |
| `Classify.js` | Maps a background path to a renderer. Shared, so nothing can disagree about what counts as "live" |
| `BgSurface.qml` | Picks the renderer and holds it |
| `MatrixRain.qml` | The rain — falling glyph columns with a head/body/tail gradient off `Color.accent` |
| `VideoSurface.qml` | `MediaPlayer` + `VideoOutput`, looping, with no audio sink attached at all |
| `bin/omarchy-matrix-preview` | Writes and tints the picker entry |

The overlay uses an empty input region (`mask: Region {}`), so clicks fall
straight through to the layer underneath and double-click-to-open-the-picker
keeps working.

Video and rain sit behind a `Loader` **source** rather than an inline component,
so `QtMultimedia` is only imported when a video is actually selected — a missing
Qt Multimedia breaks video wallpapers instead of taking the plugin down with it.

## Notes

- Selecting a video makes the stock background plugin log
  `Error decoding: …: Unsupported image format`, because it tries the same path
  as a still. Harmless — the overlay covers it completely.
- This is not Omarchy's screensaver behind your windows. `omarchy screensaver`
  runs `ttfx` in a terminal, and a terminal is an xdg-toplevel, which Hyprland
  can never stack below the background layer. The effect is reimplemented in QML
  here for that reason.

## Licence

MIT
