---------------------------------------------------
-- abilities_cooldown: profiles and settings loader
-- Reads data/profiles.lua: a hand-edited Lua file that returns one table
-- with an optional `settings` block plus one block per character. The
-- addon never writes this file, so the user's comments always survive.
--
-- Usage:
--   local config = require('ac_config')
--   config.load(report)                       -- report(msg) prints a red chat line
--   local settings = config.settings()
--   local profile, status = config.get_profile(player.name, player.main_job)
--   local main_entries, sub_entries = config.get_entries(profile, player.sub_job, report)
---------------------------------------------------
local M = {}

-- Every option a user can put in the `settings` block, with its default.
-- Colors are { red, green, blue }, each 0-255.
M.defaults = {
    warn_seconds  = 5,          -- last N seconds turn the bar to the warning color
    font          = 'Arial',
    font_size     = 11,
    bar_width     = 140,
    bar_height    = 22,
    row_spacing   = 2,
    bar_alpha     = 200,        -- 0-255, the filled part of the bar
    bg_alpha      = 168,        -- 0-255, the empty part of the bar
    text_offset_y = 0,          -- nudge row text up (negative) or down (positive)
    grow          = 'down',     -- 'down' or 'up': which way new rows stack
    colors = {
        bar   = { 255, 200, 0 },
        warn  = { 255, 60, 60 },
        text  = { 255, 255, 255 },
        track = { 0, 0, 0 },
    },
}

-- Extra rules beyond "same type as the default". Each returns true if the
-- value is acceptable.
local RULES = {
    warn_seconds  = { test = function(v) return v >= 0 end,                   text = 'a number of 0 or more' },
    font_size     = { test = function(v) return v >= 6 end,                   text = 'a number of 6 or more' },
    bar_width     = { test = function(v) return v >= 40 end,                  text = 'a number of 40 or more' },
    bar_height    = { test = function(v) return v >= 10 end,                  text = 'a number of 10 or more' },
    row_spacing   = { test = function(v) return v >= 0 end,                   text = 'a number of 0 or more' },
    bar_alpha     = { test = function(v) return v >= 0 and v <= 255 end,      text = 'a number from 0 to 255' },
    bg_alpha      = { test = function(v) return v >= 0 and v <= 255 end,      text = 'a number from 0 to 255' },
    grow          = { test = function(v) return v == 'up' or v == 'down' end, text = '"up" or "down"' },
}

local function copy_colors(colors)
    local out = {}
    for name, c in pairs(colors) do
        out[name] = { c[1], c[2], c[3] }
    end
    return out
end

local function copy_defaults()
    local out = {}
    for key, value in pairs(M.defaults) do
        if key == 'colors' then
            out.colors = copy_colors(value)
        else
            out[key] = value
        end
    end
    return out
end

local function is_color(v)
    if type(v) ~= 'table' then
        return false
    end
    for i = 1, 3 do
        local c = v[i]
        if type(c) ~= 'number' or c < 0 or c > 255 then
            return false
        end
    end
    return true
end

-- merge_settings(user, report)
-- Defaults, overridden by whatever in the user's block is valid. Anything
-- invalid or unknown gets one red message and is ignored, so a typo never
-- breaks the display.
local function merge_settings(user, report)
    local out = copy_defaults()
    if user == nil then
        return out
    end
    if type(user) ~= 'table' then
        report('settings must be a table; using the defaults')
        return out
    end

    for key, default in pairs(M.defaults) do
        local value = user[key]
        if value ~= nil then
            if key == 'colors' then
                if type(value) ~= 'table' then
                    report('settings.colors must be a table; using the default colors')
                else
                    for cname in pairs(default) do
                        local color = value[cname]
                        if color ~= nil then
                            if is_color(color) then
                                out.colors[cname] = { color[1], color[2], color[3] }
                            else
                                report('settings.colors.' .. cname .. ' must be { red, green, blue } with values 0-255; using the default')
                            end
                        end
                    end
                    for cname in pairs(value) do
                        if default[cname] == nil then
                            report('unknown color "' .. tostring(cname) .. '" in settings.colors was ignored')
                        end
                    end
                end
            elseif type(value) ~= type(default) then
                report('settings.' .. key .. ' must be a ' .. type(default) .. '; using the default')
            elseif RULES[key] and not RULES[key].test(value) then
                report('settings.' .. key .. ' must be ' .. RULES[key].text .. '; using the default')
            else
                out[key] = value
            end
        end
    end

    for key in pairs(user) do
        if M.defaults[key] == nil then
            report('unknown setting "' .. tostring(key) .. '" was ignored')
        end
    end

    return out
end

local function data_path(name)
    return windower.addon_path .. 'data/' .. name
end

-- ensure_profiles_exist(report)
-- First run: profiles.lua is not shipped (the release must never overwrite a
-- user's file), so create it from the commented example.
local function ensure_profiles_exist(report)
    local path = data_path('profiles.lua')
    local existing = io.open(path, 'r')
    if existing then
        existing:close()
        return
    end
    local source = io.open(data_path('profiles.example.lua'), 'r')
    if not source then
        report('data/profiles.example.lua is missing; reinstall the addon')
        return
    end
    local text = source:read('*a')
    source:close()
    local target = io.open(path, 'w')
    if not target then
        report('could not create data/profiles.lua')
        return
    end
    target:write(text)
    target:close()
end

-- read_profiles(path)
-- Runs the file in an empty environment: it may only build and return a
-- table, and cannot reach io, os or the rest of the game.
local function read_profiles(path)
    local chunk, err = loadfile(path)
    if not chunk then
        return nil, err
    end
    setfenv(chunk, {})
    local ok, result = pcall(chunk)
    if not ok then
        return nil, tostring(result)
    end
    if type(result) ~= 'table' then
        return nil, 'profiles.lua must end with "return { ... }"'
    end
    return result
end

-- The last good parse, kept so a typo mid-session never blanks the display.
local cache = { settings = copy_defaults(), profiles = nil }

-- load(report)
-- (Re)reads profiles.lua. On any error the previous good contents stay in
-- effect and the error (which includes the line number) is reported.
-- Returns true if the file was read successfully.
function M.load(report)
    ensure_profiles_exist(report)

    local path = data_path('profiles.lua')
    local data, err = read_profiles(path)
    if not data then
        -- Lua's message starts with the full install path; keep just the file
        -- name and the line number that follows it ("profiles.lua:3: ...").
        report((tostring(err):gsub('^.*profiles%.lua', 'profiles.lua')))
        return false
    end

    cache.settings = merge_settings(data.settings, report)
    local profiles = {}
    for key, value in pairs(data) do
        if key ~= 'settings' then
            profiles[key] = value
        end
    end
    cache.profiles = profiles
    return true
end

function M.settings()
    return cache.settings
end

-- find_key(tbl, wanted, normalize)
-- Case-insensitive lookup of a string key in a user-written table.
local function find_key(tbl, wanted, normalize)
    for key, value in pairs(tbl) do
        if type(key) == 'string' and normalize(key) == normalize(wanted) then
            return key, value
        end
    end
    return nil
end

local function lower(s)
    return s:lower()
end

local function upper(s)
    return s:upper()
end

-- get_profile(character_name, main_job)
-- Returns profile, status:
--   'ok'           the character and job both have a block
--   'no_job'       the character is listed but this job is not (empty profile)
--   'no_character' the character is not listed (profile is nil)
--   'no_config'    profiles.lua has never loaded successfully (profile is nil)
function M.get_profile(character_name, main_job)
    if not cache.profiles then
        return nil, 'no_config'
    end
    local _, character = find_key(cache.profiles, character_name, lower)
    if character == nil then
        return nil, 'no_character'
    end
    if type(character) ~= 'table' then
        return {}, 'no_job'
    end
    local _, job = find_key(character, main_job or '', upper)
    if type(job) ~= 'table' then
        return {}, 'no_job'
    end
    return job, 'ok'
end

-- normalize_entries(list, where, report)
-- Each entry is a name string, or { 'Name', label = 'Row text' }. Anything
-- else is reported and skipped. Returns the entries and how many were skipped.
local function normalize_entries(list, where, report)
    local out = {}
    local skipped = 0
    if list == nil then
        return out, skipped
    end
    if type(list) ~= 'table' then
        report(where .. ' must be a list of names')
        return out, skipped
    end
    for i, item in ipairs(list) do
        if type(item) == 'string' then
            out[#out + 1] = { spec = item }
        elseif type(item) == 'table' and type(item[1]) == 'string' then
            local label = item.label
            if label ~= nil and type(label) ~= 'string' then
                report(where .. '[' .. i .. '].label must be text; ignoring it')
                label = nil
            end
            out[#out + 1] = { spec = item[1], label = label }
        else
            skipped = skipped + 1
            report(where .. '[' .. i .. '] must be a name or { \'Name\', label = \'...\' }')
        end
    end
    return out, skipped
end

-- get_entries(profile, sub_job, report)
-- Returns the normalized main-job entries, the normalized entries for the
-- current sub job (empty when there is no sub job or no list for it), and
-- how many malformed entries were skipped across both.
function M.get_entries(profile, sub_job, report)
    local main, skipped = normalize_entries(profile.main, 'main', report)
    local sub = {}
    if profile.sub ~= nil and type(profile.sub) ~= 'table' then
        report('sub must be a table keyed by sub job, e.g. sub = { SAM = { \'Hasso\' } }')
    elseif profile.sub and sub_job then
        local key, list = find_key(profile.sub, sub_job, upper)
        if key then
            local sub_skipped
            sub, sub_skipped = normalize_entries(list, 'sub.' .. key, report)
            skipped = skipped + sub_skipped
        end
    end
    return main, sub, skipped
end

return M
