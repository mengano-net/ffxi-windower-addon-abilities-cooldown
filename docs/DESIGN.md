# Design notes

Decisions behind `abilities_cooldown`, and the questions that can only be
answered in the game. Keep this current when a decision changes.

## Why this exists

Existing cooldown displays have two problems: their configuration is XML, and
they show every ability and spell the job has. This addon is whitelist-only and
configured in a commented Lua file.

It is a Lua **addon**, not a native plugin: plugins are compiled DLLs maintained
by the Windower team, while addons are the supported route for community code.

The whitelist is also a filter on *time horizon*, not just clutter. The
abilities and spells worth a row are the ones whose recast is short enough to
change what you do in the next few seconds of a single fight, NM, Ambuscade,
or Odyssey run: shadows to reset before you get hit, a debuff like Paralyze
or Slow to refresh before it drops, Sneak/Invisible to recast before you keep
moving through a dangerous zone, a DD cooldown like Warcry worth using again
now. That is the reasoning behind rejecting two-hour abilities outright (see
below) rather than just discouraging them: a recast measured in hours cannot
inform a decision inside a single engagement, so it has no row to draw.

## Behavior

- **Whitelist only.** Only entries listed in `data/profiles.lua` are tracked.
- **Two boxes**, main job and sub job, each holding job abilities and spells in
  whitelist order. Defaults: sub box left, main box right.
- **A row is a bar** that drains from full (when the ability is used) to empty
  (when it is ready), with the name and the seconds left. It disappears when
  the ability is ready.
- **Seconds only.** Ability recasts are whole seconds. Spell recasts arrive in
  1/60-second ticks and are divided by 60. Under a minute shows `42`, from a
  minute up shows `2:22`; the number is rounded up.
- **Warning window.** The last `warn_seconds` (default 5) change the bar color.
  Color only, no blinking.
- **Bar length.** The bar's full length is the largest remaining time seen since
  the ability was last used. A reading higher than the previous one counts as a
  new use. If the addon starts mid-cooldown, that bar looks full until the
  ability is used again.
- **Two-hour abilities are rejected** (`recast_id` 0 or 254). Their cooldown is
  far longer than what this addon is for.
- **Shared recast slots** (Blood Pact, Phantom Roll, Quick Draw, Maneuvers,
  Sambas, Jigs, Steps, Stratagems) show the same countdown for every listed
  name in the group.
- **Validity.** The addon keeps no job tables of its own. It asks the game:
  `get_abilities()` for job abilities, and `get_spells()` plus the spell's job
  levels in the resource files for spells. Anything unknown, two-hour, or not
  available gets a red chat message and is skipped, never an error.
- **Lifecycle.** The player is polled at 4 Hz. A change of character, main job
  or sub job starts a 3-second settle (the game updates its ability lists a
  moment late), then the config is re-read and both lists are rebuilt. That is
  also what limits the red warnings to once per change. Logout clears the
  display. Zoning needs no handling: the addon just follows the live values.

## Configuration

- `data/profiles.lua` is hand-edited Lua that returns a table:
  `settings` plus one block per character, then per main job, with `main` and
  `sub = { SAM = {...} }` lists. The addon never writes it, so comments survive.
  It runs in an empty environment (no `os`, `io` or game access).
- It is created from `profiles.example.lua` on first run and is never shipped,
  so updating the addon cannot overwrite it.
- `data/state.json` holds the box positions and shown/hidden state. It is the
  only file the addon writes, and it is kept separate for that reason.
- Both live files are gitignored so real character names cannot be committed.
- On a syntax error the last good config stays in effect.
- There is no reload command or file watcher: use `//lua reload abilities_cooldown`.
  The file is also re-read on every job change.

## Code layout

Modules are flat and prefixed `ac_` so they cannot clash with Windower's shared
libraries (`config`, `texts`, `images`, `resources`) and do not depend on
subfolder `require`.

| File | Role |
|---|---|
| `abilities_cooldown.lua` | Entry point: events, commands, refresh loop |
| `ac_config.lua` | Loads and validates `profiles.lua` |
| `ac_resolve.lua` | Turns a whitelist name into a trackable row, or a reason it can't |
| `ac_timers.lua` | Time text, warning window, bar-maximum tracking |
| `ac_state.lua` | Reads and writes `state.json` |
| `ac_view.lua` | Draws the boxes; handles dragging |

Dragging is implemented in `ac_view.lua` rather than by the `texts`/`images`
libraries, because their built-in drag moves one object at a time and would
tear a row apart. Every object is created non-draggable.

## Testing

There is no test framework. The addon is checked by copying the folder into
Windower's `addons` folder, reloading, and trying it in the game.

This machine dual-boots into Windows for FFXI; the repo is worked on from
WSL2 against the Windows install, at:

```
/mnt/d/Program Files (x86)/Windower4/addons/abilities_cooldown
```

Run `scripts/deploy-to-windower.sh` to copy the six `.lua` modules and
`data/profiles.example.lua` there. It never touches `data/profiles.lua` or
`data/state.json` — those are the live, gitignored config and saved
positions, and overwriting them would wipe real character data. If Windower
is ever reinstalled elsewhere, override the path instead of editing the
script: `WINDOWER_ADDONS_DIR="/mnt/d/new/path/addons" scripts/deploy-to-windower.sh`.

After deploying, reload in game: `//lua reload abilities_cooldown` (or
`//lua load abilities_cooldown` if it isn't currently loaded).

## Open questions, settled by testing in the game

1. Does a solid-color rectangle (an image with no texture) draw, and does the
   text draw on top of it?
2. Is the row text vertically centered in the bar? (`text_offset_y` tunes it.)
3. Does the box drag feel right, and does it stop clicks reaching the game?
4. How do charge-based abilities (Stratagems, Quick Draw, Ready charges) report
   their recast? They may not behave like a plain cooldown.
5. Are `get_abilities()` and `get_spells()` up to date 3 seconds after a job
   change, or is a longer settle needed?
6. Do the default sizes (140 px bars, boxes at x=1007 and x=1157) suit the
   player's UI scale?
