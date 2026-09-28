-- abilities_cooldown: your whitelist and appearance settings.
--
-- The first time the addon runs it copies this file to profiles.lua, next to
-- it. Edit profiles.lua (never this example), then reload the addon:
--     //lua reload abilities_cooldown
-- The addon re-reads profiles.lua on load, login and every job change, and
-- never writes to it, so your comments are safe. If the file has a mistake,
-- the addon prints the line number in red and keeps the last good version.
--
-- Only what you list here is tracked. A row appears while that ability or
-- spell is on cooldown and disappears when it is ready.

return {

    ---------------------------------------------------------------------
    -- Appearance. Everything is optional; the values below are the
    -- defaults. Remove the leading "--" from a line to change it.
    ---------------------------------------------------------------------
    settings = {
        -- warn_seconds  = 5,            -- last N seconds turn the bar to the warning color
        -- font          = 'Arial',
        -- font_size     = 11,
        -- bar_width     = 140,          -- minimum width; a box widens to fit long labels
        -- bar_height    = 22,
        -- row_spacing   = 2,
        -- bar_alpha     = 200,          -- 0-255, the filled part of the bar
        -- bg_alpha      = 168,          -- 0-255, the empty part of the bar
        -- text_offset_y = 0,            -- nudge the text up (negative) or down (positive)
        -- grow          = 'down',       -- 'down' or 'up': which way rows stack
        -- colors = {                    -- each is { red, green, blue }, 0-255
        --     bar   = { 255, 200, 0 },  -- normal fill
        --     warn  = { 255, 60, 60 },  -- fill inside the warning window
        --     text  = { 255, 255, 255 },
        --     track = { 0, 0, 0 },      -- the empty part of the bar
        -- },
    },

    ---------------------------------------------------------------------
    -- One block per character, named exactly as in game (capitalization
    -- does not matter). Inside it, one block per MAIN job (3-letter code).
    --
    --   main = the abilities and spells tracked in the main-job box.
    --   sub  = one list per SUB job; only the list for your current sub job
    --          is used, and it goes in the sub-job box.
    --
    -- An entry is the name as it appears in game, e.g. 'Hasso' or
    -- 'Utsusemi: Ni'. To give a row different text, use a table:
    --     { 'Utsusemi: Ichi', label = 'Ichi' }
    -- If a name is both a job ability and a spell, write 'ja:Name' or
    -- 'spell:Name' to say which one you mean.
    --
    -- Order matters: rows are shown in the order you list them, and are
    -- never re-sorted by what you used last. The first name is the top row
    -- (the bottom row if grow = 'up'). Put the ones you watch most first.
    --
    -- Not supported: two-hour abilities (they are rejected with a message).
    -- A name that is misspelled, not learned, or not available to your
    -- current job, sub job or level is skipped with a red message in chat.
    ---------------------------------------------------------------------
    YourCharacter = {

        DRK = {
            main = {
                'Last Resort', 'Souleater', 'Nether Void', 'Weapon Bash',   -- job abilities
                'Drain II', 'Stun',                                         -- spells
            },
            sub = {
                SAM = { 'Hasso', 'Meditate' },
                NIN = { 'Utsusemi: Ichi', 'Utsusemi: Ni' },
            },
        },

        -- To track another job, copy a job block and change the 3-letter code:
        -- NIN = {
        --     main = {
        --         'Utsusemi: Ichi', 'Utsusemi: Ni',
        --         { 'Hojo: Ni', label = 'Hojo - Slow' },
        --     },
        --     sub = {
        --         WAR = { 'Berserk', 'Warcry' },
        --     },
        -- },
    },

    -- To add another character, copy the whole YourCharacter block and
    -- rename it:
    -- AnotherCharacter = {
    --     BLM = {
    --         main = { 'Elemental Seal', 'Stun' },
    --     },
    -- },
}
