---------------------------------------------------
-- abilities_cooldown: countdown math
-- Pure helpers with no Windower calls: time text, the warning window, and
-- per-row bar-maximum tracking.
--
-- Usage:
--   local timers  = require('ac_timers')
--   local tracker = timers.new_tracker()
--   local max     = timers.observe(tracker, 'ability:5', remaining_seconds)
--   local text    = timers.format_time(remaining_seconds)
---------------------------------------------------
local M = {}

-- Two readings closer than this are treated as the same countdown. Spell
-- recasts arrive in 1/60th-second ticks (converted to fractional seconds by
-- the caller), so consecutive readings of one countdown never rise; any rise
-- larger than this means the ability was used again.
local EPSILON = 0.01

-- format_time(seconds)
-- Whole seconds under a minute ("42"), then m:ss ("2:22"). Rounds UP so a
-- countdown never shows 0 while the ability is still on cooldown -- the same
-- rule the GearSwap HUD this addon replaces used.
function M.format_time(seconds)
    local s = math.ceil(seconds)
    if s < 0 then
        s = 0
    end
    if s < 60 then
        return tostring(s)
    end
    return string.format('%d:%02d', math.floor(s / 60), s % 60)
end

-- new_tracker() / reset(tracker)
-- A tracker remembers, per row key, the largest remaining time seen since the
-- ability was last used (the bar's "full" length) and the previous reading.
function M.new_tracker()
    return { max = {}, last = {} }
end

function M.reset(tracker)
    tracker.max = {}
    tracker.last = {}
end

-- observe(tracker, key, remaining)
-- Call once per refresh for every tracked row, including rows at 0 (ready),
-- so a finished countdown is forgotten. Returns the bar maximum for this
-- countdown, or nil when the row is ready.
--
-- A reading higher than the previous one means a new use (see EPSILON), so
-- the maximum is re-recorded. This also copes with the addon starting
-- mid-cooldown: the first reading seen becomes the maximum, so that bar
-- looks full until the ability is used again.
function M.observe(tracker, key, remaining)
    if remaining <= 0 then
        tracker.max[key] = nil
        tracker.last[key] = nil
        return nil
    end
    local last = tracker.last[key]
    if last == nil or remaining > last + EPSILON then
        tracker.max[key] = remaining
    end
    tracker.last[key] = remaining
    return tracker.max[key]
end

-- fraction(remaining, max)
-- How full the draining bar is, clamped to 0..1.
function M.fraction(remaining, max)
    if not max or max <= 0 then
        return 1
    end
    local f = remaining / max
    if f < 0 then
        return 0
    elseif f > 1 then
        return 1
    end
    return f
end

-- is_warning(remaining, warn_seconds)
-- True inside the warning window. Compares the number the player sees (the
-- rounded-up countdown), so the color change lands exactly when the text
-- reads warn_seconds.
function M.is_warning(remaining, warn_seconds)
    return math.ceil(remaining) <= warn_seconds
end

return M
