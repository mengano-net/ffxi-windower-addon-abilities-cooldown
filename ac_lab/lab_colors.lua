---------------------------------------------------
-- ac_lab: color blending
-- Turns "how close to ready" into a color between a start color (red or
-- yellow) and green. Several blend modes, so they can be compared side by
-- side in the game.
--
-- Usage:
--   local colors = require('lab_colors')
--   colors.set_start('red')
--   local c = colors.blend('hsv', progress, remaining)   -- { r, g, b }
---------------------------------------------------
local M = {}

M.YELLOW = { 255, 200, 0 }
M.RED    = { 230, 45, 35 }
M.GREEN  = { 60, 220, 60 }

M.STARTS = { red = M.RED, yellow = M.YELLOW }
M.start_name = 'red'
M.START = M.RED

-- Seconds left when 'step' mode snaps to green (the real addon's warn_seconds).
M.STEP_SECONDS = 5

M.MODES = { 'rgb', 'hsv', 'ease', 'step' }

M.DESCRIPTIONS = {
    rgb  = 'straight RGB fade (passes through a muddy olive)',
    hsv  = 'fade around the color wheel (stays bright the whole way)',
    ease = 'stays yellow, then turns green quickly near the end',
    step = 'start color, then snaps to green in the last ' .. M.STEP_SECONDS .. 's',
}

local function clamp(v, lo, hi)
    return v < lo and lo or (v > hi and hi or v)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function rgb_to_hsv(c)
    local r, g, b = c[1] / 255, c[2] / 255, c[3] / 255
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local d = max - min
    local h = 0
    if d > 0 then
        if max == r then
            h = ((g - b) / d) % 6
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h * 60
    end
    return h, max == 0 and 0 or d / max, max
end

local function hsv_to_rgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    return { math.floor((r + m) * 255 + 0.5), math.floor((g + m) * 255 + 0.5), math.floor((b + m) * 255 + 0.5) }
end

local function mix_rgb(a, b, t)
    return {
        math.floor(lerp(a[1], b[1], t) + 0.5),
        math.floor(lerp(a[2], b[2], t) + 0.5),
        math.floor(lerp(a[3], b[3], t) + 0.5),
    }
end

local SH, SS, SV = rgb_to_hsv(M.START)
local GH, GS, GV = rgb_to_hsv(M.GREEN)

-- set_start(name): 'red' or 'yellow'. Returns false for anything else.
function M.set_start(name)
    local c = M.STARTS[name]
    if not c then
        return false
    end
    M.start_name, M.START = name, c
    SH, SS, SV = rgb_to_hsv(c)
    return true
end

-- blend(mode, progress, remaining)
-- progress runs 0 (just used) to 1 (ready); remaining is seconds left.
function M.blend(mode, progress, remaining)
    local t = clamp(progress, 0, 1)
    if mode == 'hsv' then
        return hsv_to_rgb(lerp(SH, GH, t), lerp(SS, GS, t), lerp(SV, GV, t))
    elseif mode == 'ease' then
        return mix_rgb(M.START, M.GREEN, t * t * t)
    elseif mode == 'step' then
        return math.ceil(remaining) <= M.STEP_SECONDS and M.GREEN or M.START
    end
    return mix_rgb(M.START, M.GREEN, t)
end

-- shade(c, k): the color scaled by k (below 1 darker, above 1 lighter), clamped.
function M.shade(c, k)
    return {
        clamp(math.floor(c[1] * k + 0.5), 0, 255),
        clamp(math.floor(c[2] * k + 0.5), 0, 255),
        clamp(math.floor(c[3] * k + 0.5), 0, 255),
    }
end

return M
