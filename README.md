# ffxi-windower-addon-abilities-cooldown

A [Windower 4](https://www.windower.net/) addon for Final Fantasy XI that shows a
draining bar for the job abilities and spells **you choose**, and nothing else.

Most cooldown displays track everything your job has, so the box fills with
clutter. This one tracks only the whitelist you write, in a plain Lua file with
comments, per character and per job.

- Two boxes: one for your main job, one for your sub job.
- Each row is a bar that drains as the recast runs down, with the name and the
  seconds left. A row disappears the moment the ability is ready.
- The last few seconds (5 by default) turn the bar red.
- Drag a box to move it; the position is remembered.

> **Status: v0.1.0, first release candidate.** It has not been played in the
> game yet. Expect rough edges, and please report what you see.

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
    },
}
```

- An entry is the name as it appears in game. Use `{ 'Name', label = 'Text' }`
  to show different text on the row.
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
