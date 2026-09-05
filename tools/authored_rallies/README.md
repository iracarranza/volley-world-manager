# Authored rally files

These JSON files are both the hand-authoring format and the persistence format
used by `ScriptedRallyDriver.load_script_file()` and `save_script_file()`. There
is no separate export syntax to drift from what a person writes.

Run the default rally with a renderer:

```sh
xvfb-run -a godot --path . --rendering-method gl_compatibility \
  res://tools/authored_playback.tscn
```

Choose a file, playback speed, and replay presentation explicitly:

```sh
xvfb-run -a godot --path . --rendering-method gl_compatibility \
  res://tools/authored_playback.tscn -- \
  res://tools/authored_rallies/block_touch.json --speed=0.75 --replay
```

On a desktop with a native display, omit `xvfb-run -a`. Do not use `--headless`:
the purpose of this harness is to exercise the real rendered `MatchScreen`.

Coordinates are normalized court positions written as ordinary `[x, y]`
arrays. An action target may instead be an integer voli ID for receive, set,
dig, or cover. `intent_time` is the commitment moment, never a promised contact
time; neither contact height nor execution draws belong in this file.

`movement` contains requested waypoint intervals:

```json
{"actor": 2, "start_time": 0.0, "end_time": 1.0, "target": [0.8, 0.78]}
```

The production locomotion model rejects an unreachable interval. Accepted
requests are retained in the resolution audit but are not teleports. Applying
overlapping tracks to all twelve visible bodies belongs to the deferred movement
slice.

Examples:

- `probe_rally.json`: serve, receive, set, attack, visible block miss, and dig;
- `block_touch.json`: the same first attack with a resolved two-voli block touch;
- `late_reception.json`: a geometrically missed reception plus a reachable,
  overlapping movement request.
