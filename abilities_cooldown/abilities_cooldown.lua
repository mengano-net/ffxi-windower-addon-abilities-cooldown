---------------------------------------------------
-- abilities_cooldown
-- Two on-screen boxes (main job, sub job) that count down the recast of the
-- job abilities and spells you whitelist in data/profiles.lua, and nothing
-- else. Each row is a draining bar with the name and the seconds left; a row
-- disappears the moment its ability is ready again.
--
-- Load:     //lua load abilities_cooldown
-- Commands: //abilities_cooldown help
---------------------------------------------------
_addon.name     = 'Abilities Cooldown'
_addon.author   = 'Mengano'
_addon.version  = '0.1.0'
_addon.commands = { 'abilities_cooldown' }

local config  = require('ac_config')
local state   = require('ac_state')
local resolve = require('ac_resolve')
local timers  = require('ac_timers')
local view    = require('ac_view')

-- Chat colors, from Windower's own logger: red for errors, plain for info.
local COLOR_ERROR = 167
local COLOR_INFO  = 207

-- How often the boxes refresh, in seconds. The game reports whole seconds,
-- so faster than this only costs CPU.
local REFRESH_SECONDS = 0.25

-- After a login or job change, wait this long before reading the ability and
-- spell lists: the game updates them a moment later, and reading too early
-- would report valid entries as unavailable.
local SETTLE_SECONDS = 3

-- On login the player object exists well before the ability and spell lists
-- are filled in. After settling, keep waiting for real data; past this many
-- seconds give up waiting and build anyway (a level-1 job can legitimately
-- have nothing learned).
local MAX_WAIT_SECONDS = 30

local saved = state.load()        -- { visible, boxes = { main, sub } }
local settings = config.settings()
local tracker = timers.new_tracker()

local rows = { main = {}, sub = {} }   -- resolved whitelist rows per box
local counts = { main = 0, sub = 0, rejected = 0 }
local profile_status = 'not loaded yet'

local current_key = nil           -- "name|main|sub" of the last player state seen
local pending_since = nil         -- when current_key last changed (settling)
local last_refresh = 0
local debug_enabled = false
local last_debug = 0

local function report(message)
    windower.add_to_chat(COLOR_ERROR, '[abilities_cooldown] ' .. message)
end

local function say(message)
    windower.add_to_chat(COLOR_INFO, '[abilities_cooldown] ' .. message)
end

local function save_state()
    local ok, err = state.save(saved)
    if not ok then
        report('could not save data/state.json: ' .. tostring(err))
    end
end

-- Created at load time, not in a 'load' event, so the boxes always exist
-- before the first refresh.
view.init(settings, saved.boxes, function(name, x, y)
    saved.boxes[name] = { x = x, y = y }
    save_state()
end)
view.set_visible(saved.visible)

-- build_context(player)
-- What the game says the player has right now; see ac_resolve.lua.
local function build_context(player)
    local abilities = {}
    local available = windower.ffxi.get_abilities()
    if available and available.job_abilities then
        for _, id in ipairs(available.job_abilities) do
            abilities[id] = true
        end
    end
    return {
        abilities      = abilities,
        spells         = windower.ffxi.get_spells() or {},
        main_job_id    = player.main_job_id,
        main_job_level = player.main_job_level or 0,
        sub_job_id     = player.sub_job_id,
        sub_job_level  = player.sub_job_level or 0,
    }
end

-- data_ready(ctx, player)
-- True once the game has populated the lists we depend on: a real job level and
-- at least one known ability or spell. Empty lists mean "not loaded yet", and
-- resolving against them would reject every entry.
local function data_ready(ctx, player)
    if not player.main_job_id or (player.main_job_level or 0) < 1 then
        return false
    end
    if next(ctx.abilities) ~= nil then
        return true
    end
    for _, learned in pairs(ctx.spells) do
        if learned then
            return true
        end
    end
    return false
end

local function resolve_list(entries, where, ctx)
    local out = {}
    for _, entry in ipairs(entries) do
        local row, err, note = resolve.resolve(entry.spec, ctx)
        if row then
            row.label = entry.label or row.name
            out[#out + 1] = row
            if note then
                report(where .. ': ' .. note)
            end
        else
            counts.rejected = counts.rejected + 1
            report(where .. ': ' .. err)
        end
    end
    return out
end

-- clear_rows()
-- Forget everything tracked (logout, or the start of a job change).
local function clear_rows()
    rows = { main = {}, sub = {} }
    counts = { main = 0, sub = 0, rejected = 0 }
    timers.reset(tracker)
end

-- rebuild(player)
-- Re-reads profiles.lua and re-resolves both whitelists for the current
-- character, main job and sub job. Runs once after each settle, which is
-- what limits the red warnings to once per job/sub-job change.
local function rebuild(player)
    clear_rows()

    -- On an error the previous good config stays in effect.
    config.load(report)
    settings = config.settings()
    view.apply_settings(settings)

    local profile, status = config.get_profile(player.name, player.main_job)
    if status == 'no_config' then
        profile_status = 'profiles.lua has not loaded successfully'
        return
    elseif status == 'no_character' then
        profile_status = 'no profile for ' .. player.name
        report('no profile for character "' .. player.name .. '" in data/profiles.lua (add one, then //lua reload abilities_cooldown)')
        return
    elseif status == 'no_job' then
        profile_status = player.name .. ' has no ' .. tostring(player.main_job) .. ' block'
        return
    end
    profile_status = player.name .. ' ' .. tostring(player.main_job) .. '/' .. tostring(player.sub_job)

    local main_entries, sub_entries, malformed = config.get_entries(profile, player.sub_job, report)
    counts.rejected = counts.rejected + malformed
    local ctx = build_context(player)
    rows.main = resolve_list(main_entries, 'main', ctx)
    rows.sub = resolve_list(sub_entries, 'sub ' .. tostring(player.sub_job), ctx)
    counts.main = #rows.main
    counts.sub = #rows.sub
end

-- status_lines()
-- The text of the status command, one string per line. Also printed when the
-- whitelists finish loading, so a login confirms what was picked up.
local function status_lines()
    local player = windower.ffxi.get_player()
    local lines = {
        'version ' .. _addon.version .. ' | ' .. (saved.visible and 'shown' or 'hidden') .. ' | debug ' .. (debug_enabled and 'on' or 'off'),
        player and ('player: ' .. tostring(player.name) .. ' ' .. tostring(player.main_job) .. '/' .. tostring(player.sub_job)) or 'player: not logged in',
        'profile: ' .. profile_status,
        string.format('entries loaded: main %d, sub %d; rejected: %d', counts.main, counts.sub, counts.rejected),
    }
    if pending_since then
        lines[#lines + 1] = 'settling after a login or job change; the lists will load shortly'
    end
    return lines
end

-- announce()
-- Printed after every rebuild (login, job change, reload).
local function announce()
    for _, line in ipairs(status_lines()) do
        windower.add_to_chat(COLOR_INFO, 'Abilities Cooldown: ' .. line)
    end
end

-- collect(list, ability_recasts, spell_recasts, box_name)
-- Reads the live recast for each resolved row and returns the rows to draw
-- (only those still on cooldown, in whitelist order).
local function collect(list, ability_recasts, spell_recasts, box_name)
    local out = {}
    for _, row in ipairs(list) do
        -- Ability recasts are whole seconds; spell recasts are 1/60th-second
        -- ticks, so divisor is 60 for spells (see ac_resolve.lua).
        local source = row.kind == 'ability' and ability_recasts or spell_recasts
        local raw = source[row.recast_id] or 0
        local remaining = raw / row.divisor
        local max = timers.observe(tracker, row.kind .. ':' .. row.recast_id, remaining)

        if remaining > 0 then
            out[#out + 1] = {
                label    = row.label,
                time     = timers.format_time(remaining),
                fraction = timers.fraction(remaining, max),
                warn     = timers.is_warning(remaining, settings.warn_seconds),
            }
            if debug_enabled and os.clock() - last_debug >= 1 then
                say(string.format('%s | %s %s recast_id=%s raw=%s -> %.1fs', box_name, row.kind, row.name, tostring(row.recast_id), tostring(raw), remaining))
            end
        end
    end
    return out
end

local function refresh()
    local player = windower.ffxi.get_player()
    if not player then
        return
    end

    -- Any change of character, main job or sub job starts a settle; the
    -- whitelist is rebuilt once it ends.
    local key = tostring(player.name) .. '|' .. tostring(player.main_job) .. '|' .. tostring(player.sub_job)
    if key ~= current_key then
        current_key = key
        pending_since = os.clock()
        clear_rows()
    end
    if pending_since then
        local waited = os.clock() - pending_since
        if waited >= SETTLE_SECONDS and (waited >= MAX_WAIT_SECONDS or data_ready(build_context(player), player)) then
            pending_since = nil
            rebuild(player)
            announce()
        end
    end

    local ability_recasts = windower.ffxi.get_ability_recasts() or {}
    local spell_recasts = windower.ffxi.get_spell_recasts() or {}
    view.render('main', collect(rows.main, ability_recasts, spell_recasts, 'main'))
    view.render('sub', collect(rows.sub, ability_recasts, spell_recasts, 'sub'))

    if debug_enabled and os.clock() - last_debug >= 1 then
        last_debug = os.clock()
        for _, box_name in ipairs({ 'main', 'sub' }) do
            local line = view.report(box_name)
            if line then
                say(box_name .. ' box | ' .. line)
            end
        end
    end
end

local HELP = {
    'commands: //abilities_cooldown <command>',
    '  show | hide | toggle   show or hide both boxes',
    '  reset position         put both boxes back at their default spots',
    '  status                 show which profile is loaded and how many entries',
    '  debug                  toggle raw recast values in chat (for troubleshooting)',
    '  help                   this list',
    'Edit data/profiles.lua, then //lua reload abilities_cooldown (job changes re-read it too).',
}

local function set_shown(value)
    saved.visible = value
    view.set_visible(value)
    save_state()
    say(value and 'shown' or 'hidden')
end

windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or 'help'
    local args = { ... }

    if command == 'show' then
        set_shown(true)
    elseif command == 'hide' then
        set_shown(false)
    elseif command == 'toggle' then
        set_shown(not saved.visible)
    elseif command == 'reset' then
        -- "reset" and "reset position" both work.
        if args[1] == nil or args[1]:lower() == 'position' then
            saved.boxes = state.defaults().boxes
            view.set_position('main', saved.boxes.main.x, saved.boxes.main.y)
            view.set_position('sub', saved.boxes.sub.x, saved.boxes.sub.y)
            save_state()
            say('box positions reset')
        else
            report('unknown reset target "' .. tostring(args[1]) .. '" (try: reset position)')
        end
    elseif command == 'status' then
        for _, line in ipairs(status_lines()) do
            say(line)
        end
    elseif command == 'debug' then
        debug_enabled = not debug_enabled
        say('debug ' .. (debug_enabled and 'on: raw recast values print once a second while something is on cooldown' or 'off'))
    elseif command == 'help' then
        for _, line in ipairs(HELP) do
            say(line)
        end
    else
        report('unknown command "' .. command .. '"; try //abilities_cooldown help')
    end
end)

windower.register_event('prerender', function()
    local now = os.clock()
    if now - last_refresh < REFRESH_SECONDS then
        return
    end
    last_refresh = now
    refresh()
end)

windower.register_event('logout', function()
    current_key = nil
    pending_since = nil
    clear_rows()
    profile_status = 'not logged in'
    view.render('main', {})
    view.render('sub', {})
end)

windower.register_event('unload', function()
    view.destroy()
end)
