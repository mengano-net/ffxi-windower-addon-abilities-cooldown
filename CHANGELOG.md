# Changelog

## 0.1.0 (unreleased)

First implementation. Not yet tried in the game.

- Two boxes (main job, sub job) with a draining bar, name and seconds left per row.
- Whitelist-only tracking of job abilities and spells from a commented Lua file,
  per character and main job, with sub-job lists.
- Red warning window (default last 5 seconds); rows disappear when ready.
- Two-hour abilities and unavailable or unknown entries are rejected with a red
  chat message.
- Draggable boxes with saved positions.
- Each box widens to fit its longest label and countdown; `bar_width` is the minimum.
- Rows keep the order of the profile lists (documented in the README).
- Labels longer than 32 characters are cut, so a box never grows past that.
- Commands: `show`, `hide`, `toggle`, `reset position`, `status`, `debug`, `help`.
