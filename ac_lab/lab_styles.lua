---------------------------------------------------
-- ac_lab: bar styles under test
-- Each style draws one row (a name and a countdown) its own way. They all take
-- the same per-frame state, so they can be compared side by side and
-- benchmarked against each other.
--
-- Usage:
--   local styles = require('lab_styles')
--   local row = styles.list[1].new({ x = 100, y = 200, w = 160, h = 22, font = 'Arial', font_size = 11 })
--   row.update({ label = 'Hasso', time = '12', fraction = 0.6, progress = 0.4,
--                color = { 255, 200, 0 }, remaining = 12, ready = false, now = os.clock() })
--   row.destroy()
--
-- fraction is time left over the full recast (1 -> 0); progress is the
-- opposite (0 -> 1). row.objects is how many texts and images the row uses.
---------------------------------------------------
local texts  = require('texts')
local images = require('images')
local colors = require('lab_colors')

local M = {}

local DARK  = { 0, 0, 0 }
local WHITE = { 255, 255, 255 }
local TEXT_PAD = 4

---------------------------------------------------
-- Building blocks. Every setter remembers what it last sent and skips the
-- call when nothing changed, the same way ac_view does. Only solid
-- rectangles: textured images draw as a flat tint in game (see DESIGN.md).
---------------------------------------------------

-- new_row(ctx): a container that tracks its objects so destroy() gets them all.
local function new_row(ctx)
    local row = { ctx = ctx, parts = {}, objects = 0 }

    function row.rect(color, alpha)
        local img = images.new({
            pos       = { x = ctx.x, y = ctx.y },
            color     = { alpha = alpha, red = color[1], green = color[2], blue = color[3] },
            size      = { width = ctx.w, height = ctx.h },
            texture   = { path = '', fit = false },
            draggable = false,
        })
        img:show()
        local part = { kind = 'image', obj = img, x = ctx.x, y = ctx.y, w = ctx.w, h = ctx.h, a = alpha,
                       c = color[1] * 65536 + color[2] * 256 + color[3], on = true }
        row.parts[#row.parts + 1] = part
        row.objects = row.objects + 1
        return part
    end

    function row.text(right_aligned, color)
        local c = color or WHITE
        local t = texts.new('', {
            pos     = { x = 0, y = 0 },
            bg      = { visible = false },
            flags   = { draggable = false, right = right_aligned, bold = false },
            text    = {
                size = ctx.font_size, font = ctx.font, alpha = 255,
                red = c[1], green = c[2], blue = c[3],
                stroke = { width = 2, alpha = 255, red = 0, green = 0, blue = 0 },
            },
            padding = 0,
        })
        t:show()
        local part = { kind = 'text', obj = t, value = '', c = c[1] * 65536 + c[2] * 256 + c[3] }
        row.parts[#row.parts + 1] = part
        row.objects = row.objects + 1
        return part
    end

    -- name_and_time(color): the usual pair, vertically centered in the bar.
    function row.name_and_time(color)
        local name = row.text(false, color)
        local time = row.text(true, color)
        local text_y = ctx.y + math.floor((ctx.h - ctx.font_size * 1.5) / 2)
        name.obj:pos(ctx.x + TEXT_PAD, text_y)
        time.obj:pos(ctx.x + ctx.w - TEXT_PAD, text_y)
        return name, time
    end

    function row.destroy()
        for _, part in ipairs(row.parts) do
            part.obj:destroy()
        end
        row.parts = {}
    end

    return row
end

-- place(part, x, y, w, h): move/resize an image. A width under 1 hides it.
local function place(part, x, y, w, h)
    local on = w >= 1 and h >= 1
    if part.on ~= on then
        part.on = on
        if on then part.obj:show() else part.obj:hide() end
    end
    if not on then
        return
    end
    if part.x ~= x or part.y ~= y then
        part.obj:pos(x, y)
        part.x, part.y = x, y
    end
    if part.w ~= w or part.h ~= h then
        part.obj:size(w, h)
        part.w, part.h = w, h
    end
end

-- paint(part, color, alpha): recolor an image or a text.
local function paint(part, color, alpha)
    local key = color[1] * 65536 + color[2] * 256 + color[3]
    if part.c ~= key then
        part.obj:color(color[1], color[2], color[3])
        part.c = key
    end
    if alpha and part.a ~= alpha then
        part.obj:alpha(alpha)
        part.a = alpha
    end
end

local function write(part, value)
    if part.value ~= value then
        part.obj:text(value)
        part.value = value
    end
end

local function fill_width(w, fraction)
    return math.floor(w * fraction + 0.5)
end

-- pulse(now, lo, hi): an alpha that breathes between lo and hi, ~1.5 times a second.
local function pulse(now, lo, hi)
    return math.floor(lo + (hi - lo) * (0.5 + 0.5 * math.sin(now * 9)) + 0.5)
end

---------------------------------------------------
-- The styles
---------------------------------------------------
M.list = {}

local function style(name, desc, new)
    M.list[#M.list + 1] = { name = name, desc = desc, new = new }
end

style('flat', 'filled draining box (the addon\'s style = \'bar\')', function(ctx)
    local row = new_row(ctx)
    row.rect(DARK, 168)
    local fill = row.rect(colors.YELLOW, 200)
    local name, time = row.name_and_time()
    function row.update(s)
        place(fill, ctx.x, ctx.y, fill_width(ctx.w, s.fraction), ctx.h)
        paint(fill, s.color)
        write(name, s.label)
        write(time, s.time)
    end
    return row
end)

style('charge', 'fills UP toward ready instead of draining', function(ctx)
    local row = new_row(ctx)
    row.rect(DARK, 168)
    local fill = row.rect(colors.YELLOW, 200)
    local name, time = row.name_and_time()
    function row.update(s)
        place(fill, ctx.x, ctx.y, s.ready and ctx.w or fill_width(ctx.w, s.progress), ctx.h)
        paint(fill, s.color)
        write(name, s.label)
        write(time, s.time)
    end
    return row
end)

style('tint', 'whole box changes color, no bar', function(ctx)
    local row = new_row(ctx)
    local box = row.rect(colors.YELLOW, 210)
    local name, time = row.name_and_time()
    function row.update(s)
        paint(box, s.color, s.ready and pulse(s.now, 120, 230) or 210)
        write(name, s.label)
        write(time, s.time)
    end
    return row
end)

style('text', 'dark box, only the text changes color', function(ctx)
    local row = new_row(ctx)
    row.rect(DARK, 168)
    local name, time = row.name_and_time(colors.YELLOW)
    function row.update(s)
        paint(name, s.color)
        paint(time, s.color)
        write(name, s.label)
        write(time, s.time)
    end
    return row
end)

style('bevel', 'layered rectangles: outline, highlight, shadow', function(ctx)
    local row = new_row(ctx)
    local outline = row.rect(DARK, 255)
    place(outline, ctx.x - 1, ctx.y - 1, ctx.w + 2, ctx.h + 2)
    row.rect(DARK, 150)
    local fill = row.rect(colors.YELLOW, 220)
    local hi_h = math.floor(ctx.h * 0.4)
    local lo_h = math.floor(ctx.h * 0.25)
    local hi = row.rect(WHITE, 70)
    local lo = row.rect(DARK, 90)
    local name, time = row.name_and_time()
    function row.update(s)
        local w = fill_width(ctx.w, s.fraction)
        place(fill, ctx.x, ctx.y, w, ctx.h)
        place(hi, ctx.x, ctx.y, w, hi_h)
        place(lo, ctx.x, ctx.y + ctx.h - lo_h, w, lo_h)
        paint(fill, s.color)
        write(name, s.label)
        write(time, s.time)
    end
    return row
end)

style('pips', '10 segments light up as it gets closer', function(ctx)
    local row = new_row(ctx)
    local N, GAP = 10, 2
    local seg_w = math.floor((ctx.w - GAP * (N - 1)) / N)
    local segs = {}
    for i = 1, N do
        segs[i] = row.rect(DARK, 150)
        place(segs[i], ctx.x + (i - 1) * (seg_w + GAP), ctx.y, seg_w, ctx.h)
    end
    local name, time = row.name_and_time()
    function row.update(s)
        local lit = s.ready and N or math.floor(s.progress * N)
        for i = 1, N do
            if i <= lit then
                paint(segs[i], s.color, 220)
            else
                paint(segs[i], DARK, 150)
            end
        end
        write(name, s.label)
        write(time, s.time)
    end
    return row
end)

-- underline(opt): just text, with a line underneath. The variants below are
-- all this one style with different options:
--   line_h  line thickness in pixels (default 4)
--   charge  the line grows toward ready instead of draining
--   center  the line shrinks toward its middle instead of toward the left
--   tint    the text takes the line's color too
--   glow    a soft halo of the line's color rises above it (solid bands
--           that fade out upward)
--   pulse   the line breathes in the last PULSE_SECONDS and when ready
local PULSE_SECONDS = 3
-- Glow bands, bottom (on the line) to top: each 2px, fading out upward.
local GLOW_ALPHAS = { 150, 105, 70, 40, 18 }
local GLOW_BAND_H = 2

local function underline(opt)
    return function(ctx)
        local row = new_row(ctx)
        local line_h = opt.line_h or 4
        local line_y = ctx.y + ctx.h - line_h
        local track = row.rect(DARK, 200)
        place(track, ctx.x, line_y, ctx.w, line_h)
        local glow = {}
        if opt.glow then
            for i = 1, #GLOW_ALPHAS do
                glow[i] = row.rect(colors.YELLOW, GLOW_ALPHAS[i])
            end
        end
        local fill = row.rect(colors.YELLOW, 255)
        local name, time = row.name_and_time()
        -- Lift the text so it sits on the line instead of through it.
        local text_y = line_y - math.floor(ctx.font_size * 1.6)
        name.obj:pos(ctx.x, text_y)
        time.obj:pos(ctx.x + ctx.w, text_y)

        function row.update(s)
            local amount = opt.charge and s.progress or s.fraction
            if s.ready then
                amount = 1   -- a full green line while it says READY
            end
            local w = fill_width(ctx.w, amount)
            local x = opt.center and ctx.x + math.floor((ctx.w - w) / 2) or ctx.x
            local alpha = 255
            if opt.pulse and (s.ready or s.remaining <= PULSE_SECONDS) then
                alpha = pulse(s.now, 110, 255)
            end
            place(fill, x, line_y, w, line_h)
            paint(fill, s.color, alpha)
            for i, band in ipairs(glow) do
                place(band, x, line_y - i * GLOW_BAND_H, w, GLOW_BAND_H)
                paint(band, s.color, math.floor(alpha * GLOW_ALPHAS[i] / 255))
            end
            if opt.tint then
                paint(name, s.color)
                paint(time, s.color)
            end
            write(name, s.label)
            write(time, s.time)
        end
        return row
    end
end

style('underline',    'just text, with a thin bar underneath',        underline({}))
style('under-thick',  'thicker 7px line (what the addon ships)',     underline({ line_h = 7 }))
style('under-hair',   'hairline 2px, pulses near ready',              underline({ line_h = 2, pulse = true }))
style('under-charge', 'line grows toward ready instead of draining',  underline({ charge = true }))
style('under-center', 'line shrinks toward its middle',               underline({ center = true }))
style('under-tint',   'text takes the line color too',                underline({ tint = true }))
style('under-glow',   'soft halo of color rising above the line',     underline({ glow = true }))
style('under-pulse',  'glow + pulses in the last ' .. PULSE_SECONDS .. 's and when ready',
                                                                      underline({ glow = true, pulse = true }))

return M
