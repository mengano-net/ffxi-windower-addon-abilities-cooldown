---------------------------------------------------
-- abilities_cooldown: whitelist name resolution
-- Turns one whitelist entry ("Hasso", "Utsusemi: Ni", "spell:Stun") into a
-- row the display can track, or explains why it can't. The addon keeps no
-- tables of its own about which job can use what: availability is asked of
-- the game (get_abilities / get_spells) and of Windower's resource files.
--
-- Usage:
--   local resolve = require('ac_resolve')
--   local row, err, note = resolve.resolve('Hasso', ctx)
--
-- ctx (built once per rebuild by the caller):
--   abilities      set: ability id -> true   (get_abilities().job_abilities)
--   spells         table: spell id -> true   (get_spells())
--   main_job_id, main_job_level, sub_job_id, sub_job_level
--
-- Returns:
--   row  { kind = 'ability'|'spell', id, recast_id, name, divisor }, or nil
--   err  why the entry was rejected (nil on success)
--   note a warning worth showing even though the entry was accepted
---------------------------------------------------
local res = require('resources')

local M = {}

-- Lower-cased name -> { ability = { entries }, spell = { entries } }, built
-- once on first use. Names are matched case-insensitively.
local index

-- Two-hour abilities share these recast slots (0 = "SP Ability", 254 = "SP
-- Ability II"). Their cooldown is far too long for what this addon is for,
-- so they are rejected on purpose.
local TWO_HOUR_RECAST_IDS = { [0] = true, [254] = true }

local function trim(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function add(name_lower, kind, entry)
    local slot = index[name_lower]
    if not slot then
        slot = { ability = {}, spell = {} }
        index[name_lower] = slot
    end
    slot[kind][#slot[kind] + 1] = entry
end

local function build_index()
    index = {}
    for _, ability in pairs(res.job_abilities) do
        -- 'Monster' entries are mob-only moves that reuse player ability names.
        if ability.en and ability.type ~= 'Monster' then
            add(ability.en:lower(), 'ability', ability)
        end
    end
    for _, spell in pairs(res.spells) do
        if spell.en then
            add(spell.en:lower(), 'spell', spell)
        end
    end
end

-- spell_available(spell, ctx)
-- Learned, and castable at the current main or sub job and level. A spell you
-- cannot cast reads as recast 0 -- identical to "ready" -- so without this
-- check a bad entry would silently never show.
local function spell_available(spell, ctx)
    if not ctx.spells[spell.id] then
        return false
    end
    local levels = spell.levels
    if type(levels) ~= 'table' then
        return false
    end
    local main_needed = ctx.main_job_id and levels[ctx.main_job_id]
    if main_needed and ctx.main_job_level >= main_needed then
        return true
    end
    local sub_needed = ctx.sub_job_id and levels[ctx.sub_job_id]
    if sub_needed and ctx.sub_job_level >= sub_needed then
        return true
    end
    return false
end

-- first_available(list, test)
local function first_available(list, test)
    for _, entry in ipairs(list) do
        if test(entry) then
            return entry
        end
    end
    return nil
end

-- resolve(spec, ctx): see the header for the return values.
function M.resolve(spec, ctx)
    if type(spec) ~= 'string' or trim(spec) == '' then
        return nil, 'entry has no name'
    end
    if not index then
        build_index()
    end

    -- Optional "ja:" / "spell:" prefix. Checked by exact prefix so names that
    -- contain a colon ("Utsusemi: Ni", "Blood Pact: Rage") are left alone.
    local name = trim(spec)
    local kind = nil
    local lower = name:lower()
    if lower:sub(1, 3) == 'ja:' then
        kind = 'ability'
        name = trim(name:sub(4))
    elseif lower:sub(1, 6) == 'spell:' then
        kind = 'spell'
        name = trim(name:sub(7))
    end

    local slot = index[name:lower()]
    if not slot then
        return nil, '"' .. name .. '" is not a known ability or spell name'
    end

    local abilities = slot.ability
    local spells = slot.spell
    if kind == 'ability' then
        spells = {}
    elseif kind == 'spell' then
        abilities = {}
    end
    if #abilities == 0 and #spells == 0 then
        return nil, '"' .. name .. '" is not a ' .. (kind == 'ability' and 'job ability' or 'spell')
    end

    -- Drop two-hour abilities. If that was all there was, say so.
    local trackable = {}
    for _, ability in ipairs(abilities) do
        if not TWO_HOUR_RECAST_IDS[ability.recast_id] then
            trackable[#trackable + 1] = ability
        end
    end
    if #trackable == 0 and #spells == 0 then
        return nil, '"' .. name .. '" is a two-hour ability, which is not tracked'
    end

    local ability = first_available(trackable, function(a)
        return ctx.abilities[a.id] == true
    end)
    local spell = first_available(spells, function(s)
        return spell_available(s, ctx)
    end)

    local note = nil
    if ability and spell then
        note = '"' .. name .. '" is both a job ability and a spell; tracking the job ability (use "ja:" or "spell:" to choose)'
        spell = nil
    end

    if ability then
        if ability.recast_id == nil then
            return nil, '"' .. name .. '" has no recast data'
        end
        return { kind = 'ability', id = ability.id, recast_id = ability.recast_id, name = ability.en, divisor = 1 }, nil, note
    elseif spell then
        if spell.recast_id == nil then
            return nil, '"' .. name .. '" has no recast data'
        end
        -- get_spell_recasts() reports 1/60th-second ticks; the caller divides
        -- by this to get whole seconds.
        return { kind = 'spell', id = spell.id, recast_id = spell.recast_id, name = spell.en, divisor = 60 }, nil, note
    end

    return nil, '"' .. name .. '" is not available to your current job, sub job or level (or not learned)'
end

return M
