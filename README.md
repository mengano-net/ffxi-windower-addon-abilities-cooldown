# ffxi-windower-addon-abilities-cooldown

A [Windower 4](https://www.windower.net/) addon for Final Fantasy XI that shows a
draining bar for the job abilities and spells **you choose**, and nothing else.

Most cooldown displays track everything your job has, so the box fills with
clutter. This one tracks only the whitelist you write, in a plain Lua file with
comments, per character and per job/sub-job.

- Two boxes: one for your main job, one for your sub job.
- Each row is a bar that drains as the recast runs down, with the name and the
  seconds left. A row disappears the moment the ability is ready.
- The last few seconds (5 by default) turn the bar red.
- Drag a box to move it; the position is remembered.

## What this tracks (and what it doesn't)

This addon is for the recasts that matter **inside a single fight or run** —
a notorious monster, an Ambuscade, a run through Odyssey — where "when can I
do that again" changes what you do in the next few seconds:

- **Am I about to get hit?** Utsusemi is down and you need to know the moment
  a fresh set of shadows is up.
- **Is a buff about to fall off?** Paralyze, Slow, or another debuff needs
  recasting before it drops so the fight doesn't slip out of control.
- **Can I still move safely?** Sneak or Invisible came off mid-transit and
  you need to know when you can recast it before you keep walking.
- **Is my damage cooldown back?** As a DD, Warcry, a weapon skill setup
  ability, or similar is up again and worth using now rather than later.

Everything here is on the order of seconds to a couple of minutes — exactly
the window where watching a bar is more useful than checking a timer in your
head.

**Two-hour abilities are intentionally out of scope** and are rejected if you
try to whitelist them. A cooldown that long has no bearing on a single
engagement: by the time it's back up, the fight, run, or session that
mattered is long over. Track those elsewhere (or just remember them); this
addon stays focused on what's actionable *right now*.

## Install

1. Download the release zip (or copy the `abilities_cooldown` folder from this
   repository).
2. Put the **`abilities_cooldown`** folder inside your Windower `addons` folder,
   so you end up with `Windower4/addons/abilities_cooldown/abilities_cooldown.lua`.
3. In game: `//lua load abilities_cooldown`
4. To load it automatically, add `abilities_cooldown` to your addon autoload
   list (Windower launcher profile, or the `<autoload>` section of `settings.xml`).

The first time it runs it creates `data/profiles.lua` from the example next to it.

## Configure

Edit `addons/abilities_cooldown/data/profiles.lua`, then reload:
`//lua reload abilities_cooldown`. The addon also re-reads the file whenever your
job or sub job changes.

```lua
return {
    YourCharacter = {                 -- your character's name, as in game
        DRK = {                       -- your main job
            main = { 'Last Resort', 'Souleater', 'Drain II', 'Stun' },
            sub  = {
                SAM = { 'Hasso', 'Meditate' },       -- used while your sub job is SAM
                NIN = { 'Utsusemi: Ichi', { 'Utsusemi: Ni', label = 'Ni' } },
            },
        },
        BLM = {                       -- another main job on the same character
            main = { 'Elemental Seal', 'Sleep II', 'Stun' },
            sub  = {
                RDM = { 'Refresh' },              -- used while your sub job is RDM
                WHM = { 'Silence' },               -- used while your sub job is WHM
            },
        },
    },
}
```

- An entry is the name as it appears in game. Use `{ 'Name', label = 'Text' }`
  to show different text on the row.
- **Order matters.** Rows appear in exactly the order you list them; the addon
  never re-sorts them by what you used last. The first name in a list is the top
  row (the bottom row if you set `grow = 'up'`), and rows for abilities that
  are ready are simply skipped. Put the ones you watch most first. Each list
  (`main`, and each sub job's list) is ordered on its own.
- If a name is both a job ability and a spell, write `'ja:Name'` or `'spell:Name'`.
- Two-hour abilities are not tracked; they are rejected with a message.
- A name that is misspelled, not learned, or not available to your current job,
  sub job or level is skipped, with a red message in chat.
- The file also takes an optional `settings` block (colors, sizes, the warning
  window). Every option is listed, commented out, in
  [`data/profiles.example.lua`](abilities_cooldown/data/profiles.example.lua).
- If the file has a mistake, the addon prints the line number in red and keeps
  using the last version that worked.

## Commands

`//abilities_cooldown <command>`

| Command | What it does |
|---|---|
| `show`, `hide`, `toggle` | Show or hide both boxes |
| `reset position` | Put both boxes back at their default spots |
| `status` | Show the loaded profile and how many entries loaded or were rejected |
| `debug` | Toggle raw recast values in chat, for troubleshooting |
| `help` | List the commands |

## Contributing

Only invited collaborators can open pull requests on this repository, and
`main` is protected: changes arrive through a feature branch and a pull request.

## License

[MIT](LICENSE)
