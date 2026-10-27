---------------------------------------------------
-- abilities_cooldown: on-screen boxes
-- Draws the two boxes (main job, sub job). Each row is four objects: an
-- image for the empty bar, an image for the filled part, and two texts (the
-- name on the left, the countdown right-aligned). Rows are pooled and
-- reused; unused ones are just hidden.
--
-- Two styles share those objects. 'underline' draws the text over a thin
-- line; 'bar' draws it inside a filled box. Either way the fill drains as the
-- recast runs down and fades from colors.start to colors.ready.
--
-- Behind each box sits an optional panel: a grey gradient, sized to the rows
-- currently shown. Textured images draw as flat color in game (the texture
-- is ignored), so the gradient is a stack of thin solid rectangles.

-- Rectangles in a panel's gradient. Enough that each step is a couple of
-- grey levels, too small to show as stripes.
local PANEL_BANDS = 16
--
-- Dragging is handled here, not by the texts/images libraries: their built-in
-- drag moves one object at a time, which would tear a row apart. Every object
-- is created non-draggable, and one mouse handler moves a whole box.
--
-- Usage:
--   local view = require('ac_view')
--   view.init(settings, state.boxes, function(name, x, y) ... end)
--   view.render('main', { { label = 'Hasso', time = '42', fraction = 0.7 } })
---------------------------------------------------
local texts  = require('texts')
local images = require('images')

local M = {}

-- Horizontal gap between the bar's edge and its text.
local TEXT_PAD = 4

-- Smallest space kept between a row's name and its countdown.
local TEXT_GAP = 0

-- Longest label drawn, in characters. Anything longer in the user's profile is
-- cut to this, so one long label cannot stretch the box across the screen.
local MAX_LABEL_CHARS = 32

-- Pixels taken back off the fitted width. The measured text runs a little
-- wider than it draws, so without this the bar ends too far past the text.
local WIDTH_TRIM = 16

-- The underline style's line is fully opaque over a darker track, which reads
-- better at a few pixels tall than the bar style's see-through fill.
-- (bar_alpha and bg_alpha only apply to the bar style.)
local LINE_ALPHA  = 255
local TRACK_ALPHA = 200

-- Space between the rows and the panel's edge. The top needs more: in the
-- underline style the text rises a few pixels above the row's slot.
local PANEL_PAD_X      = 8
local PANEL_PAD_TOP    = 8
local PANEL_PAD_BOTTOM = 6

local settings
local boxes = {}
local visible = true
local on_moved
local drag

local function underline()
    return settings.style == 'underline'
end

-- Height of the drawn fill and track: the whole bar, or just the line.
local function fill_height()
    return underline() and settings.line_height or settings.bar_height
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
    return math.floor((r + m) * 255 + 0.5), math.floor((g + m) * 255 + 0.5), math.floor((b + m) * 255 + 0.5)
end

-- fade(progress): the fill color, 0 = just used (start) to 1 = ready.
-- Blends hue, saturation and brightness rather than red/green/blue, so the
-- colors in between stay bright instead of going muddy.
local function fade(progress)
    local h1, s1, v1 = rgb_to_hsv(settings.colors.start)
    local h2, s2, v2 = rgb_to_hsv(settings.colors.ready)
    local t = math.max(0, math.min(1, progress))
    return hsv_to_rgb(h1 + (h2 - h1) * t, s1 + (s2 - s1) * t, v1 + (v2 - v1) * t)
end

-- make_panel()
-- The gradient behind a box: PANEL_BANDS rectangles, top to bottom, each
-- colored a step closer from background_top to background_bottom. nil when
-- background is off. Starts hidden. It must be created before the box's
-- rows: images draw in creation order.
local function make_panel()
    if not settings.background then
        return nil
    end
    local top, bottom = settings.colors.background_top, settings.colors.background_bottom
    local bands = {}
    for i = 1, PANEL_BANDS do
        local t = (i - 0.5) / PANEL_BANDS
        local band = images.new({
            pos       = { x = 0, y = 0 },
            color     = {
                alpha = settings.background_alpha,
                red   = math.floor(top[1] + (bottom[1] - top[1]) * t + 0.5),
                green = math.floor(top[2] + (bottom[2] - top[2]) * t + 0.5),
                blue  = math.floor(top[3] + (bottom[3] - top[3]) * t + 0.5),
            },
            size      = { width = settings.bar_width, height = 1 },
            texture   = { path = '', fit = false },
            draggable = false,
        })
        band:hide()
        bands[i] = band
    end
    return bands
end

local function new_box(name, position)
    return {
        name = name, x = position.x, y = position.y, rows = {}, shown = 0,
        width = settings.bar_width, -- grows to fit the longest label; see fit_width
        time_w = 0,                 -- widest countdown text seen so far
        panel = make_panel(),
    }
end

-- panel_rect(box): x, y, width, height around the rows currently shown.
-- Also the area that starts a drag.
local function panel_rect(box)
    local step = settings.bar_height + settings.row_spacing
    local rows_h = (box.shown - 1) * step + settings.bar_height
    local top = settings.grow == 'up' and box.y - (box.shown - 1) * step or box.y
    return box.x - PANEL_PAD_X, top - PANEL_PAD_TOP,
        box.width + 2 * PANEL_PAD_X, rows_h + PANEL_PAD_TOP + PANEL_PAD_BOTTOM
end

-- update_panel(box): fit the panel to the shown rows, or hide it when the
-- box is empty. Skips the calls when nothing changed.
local function update_panel(box)
    local panel = box.panel
    if not panel then
        return
    end
    local on = box.shown > 0
    if not on then
        if box.panel_on then
            for _, band in ipairs(panel) do
                band:hide()
            end
            box.panel_on, box.panel_key = false, nil
        end
        return
    end
    local x, y, w, h = panel_rect(box)
    local key = x .. ',' .. y .. ',' .. w .. ',' .. h
    if box.panel_key == key then
        return
    end
    box.panel_key, box.panel_on = key, true
    -- Split the height between the bands; a band left with no height (a
    -- panel shorter than PANEL_BANDS pixels) is hidden.
    for i, band in ipairs(panel) do
        local y0 = y + math.floor(h * (i - 1) / PANEL_BANDS)
        local y1 = y + math.floor(h * i / PANEL_BANDS)
        if y1 > y0 then
            band:pos(x, y0)
            band:size(w, y1 - y0)
            band:show()
        else
            band:hide()
        end
    end
end

local function destroy_panel(box)
    if box.panel then
        for _, band in ipairs(box.panel) do
            band:destroy()
        end
        box.panel = nil
    end
    box.panel_on, box.panel_key = nil, nil
end

-- make_bar(color, alpha)
-- A solid rectangle: an image with no texture. Starts hidden.
local function make_bar(color, alpha)
    return images.new({
        pos       = { x = 0, y = 0 },
        color     = { alpha = alpha, red = color[1], green = color[2], blue = color[3] },
        size      = { width = settings.bar_width, height = fill_height() },
        texture   = { path = '', fit = false },
        draggable = false,
    })
end

-- make_text(right_aligned)
-- Text with no background. When right-aligned, its x position is its right edge.
local function make_text(right_aligned)
    local c = settings.colors.text
    return texts.new('', {
        pos     = { x = 0, y = 0 },
        bg      = { visible = false },
        flags   = { draggable = false, right = right_aligned, bold = false },
        text    = {
            size   = settings.font_size,
            font   = settings.font,
            alpha  = 255,
            red    = c[1],
            green  = c[2],
            blue   = c[3],
            stroke = { width = 2, alpha = 255, red = 0, green = 0, blue = 0 },
        },
        padding = 0,
    })
end

-- make_row()
-- Creation order matters: the empty bar first, then the fill, so the fill
-- draws on top of it.
local function make_row()
    local row = {}
    if underline() then
        row.track = make_bar(settings.colors.track, TRACK_ALPHA)
        row.fill  = make_bar(settings.colors.start, LINE_ALPHA)
    else
        row.track = make_bar(settings.colors.track, settings.bg_alpha)
        row.fill  = make_bar(settings.colors.start, settings.bar_alpha)
    end
    row.name  = make_text(false)
    row.time  = make_text(true)
    row.on    = false
    return row
end

local function destroy_row(row)
    row.track:destroy()
    row.fill:destroy()
    row.name:destroy()
    row.time:destroy()
end

local function set_row_visible(row, on)
    if row.on == on then
        return
    end
    row.on = on
    if on then
        row.track:show()
        row.fill:show()
        row.name:show()
        row.time:show()
    else
        row.track:hide()
        row.fill:hide()
        row.name:hide()
        row.time:hide()
    end
end

-- place_row(box, row, index)
-- Positions one row (index counts from 0). Skips the calls when nothing moved.
local function place_row(box, row, index)
    local step = settings.bar_height + settings.row_spacing
    local x = box.x
    local y = box.y + (settings.grow == 'up' and -index or index) * step
    if row.x == x and row.y == y and row.placed_width == box.width then
        return
    end
    row.x, row.y, row.placed_width = x, y, box.width
    if underline() then
        -- The line sits at the bottom of the row's slot, the text just above it.
        local line_y = y + settings.bar_height - settings.line_height
        local text_y = line_y - math.floor(settings.font_size * 1.6) + settings.text_offset_y
        row.track:pos(x, line_y)
        row.fill:pos(x, line_y)
        row.name:pos(x, text_y)
        row.time:pos(x + box.width, text_y)
    else
        row.track:pos(x, y)
        row.fill:pos(x, y)
        -- Roughly centers the text vertically in the bar; text_offset_y tunes it.
        local text_y = y + math.floor((settings.bar_height - settings.font_size * 1.5) / 2) + settings.text_offset_y
        row.name:pos(x + TEXT_PAD, text_y)
        row.time:pos(x + box.width - TEXT_PAD, text_y)
    end
end

local function reposition(box)
    for i = 1, box.shown do
        place_row(box, box.rows[i], i - 1)
    end
    update_panel(box)
end

-- init(new_settings, positions, moved_callback)
-- positions: { main = { x, y }, sub = { x, y } }. moved_callback(name, x, y)
-- is called when the user finishes dragging a box.
function M.init(new_settings, positions, moved_callback)
    settings = new_settings
    on_moved = moved_callback
    boxes.main = new_box('main', positions.main)
    boxes.sub = new_box('sub', positions.sub)
end

-- apply_settings(new_settings)
-- Sizes, fonts and colors are baked into the objects at creation, so a
-- settings change throws the pool away; render() rebuilds rows as needed.
function M.apply_settings(new_settings)
    settings = new_settings
    for _, box in pairs(boxes) do
        for _, row in ipairs(box.rows) do
            destroy_row(row)
        end
        box.rows = {}
        box.shown = 0
        box.width = settings.bar_width
        box.time_w = 0
        -- New panel before any new row, so it stays underneath.
        destroy_panel(box)
        box.panel = make_panel()
    end
end

function M.set_visible(value)
    visible = value
end

-- set_position(name, x, y)
function M.set_position(name, x, y)
    local box = boxes[name]
    box.x, box.y = x, y
    reposition(box)
end

-- fit_width(box, count)
-- The bar is never narrower than bar_width, but widens so the longest label
-- and a countdown fit with room between them. All rows in a box share one
-- width so the box stays a tidy column.
local function fit_width(box, count)
    local widest = 0
    for i = 1, count do
        widest = math.max(widest, box.rows[i].name_w or 0)
    end
    local needed = math.ceil(widest + TEXT_GAP + box.time_w + 2 * TEXT_PAD) - WIDTH_TRIM
    box.width = math.max(settings.bar_width, needed)
end

-- report(name)
-- One line of measured sizes for the debug command, or nil when the box is empty.
function M.report(name)
    local box = boxes[name]
    if box.shown == 0 then
        return nil
    end
    local parts = {}
    for i = 1, box.shown do
        parts[#parts + 1] = tostring(box.rows[i].name_w)
    end
    return string.format('width=%d (min %d) time_w=%s name_w=[%s]',
        box.width, settings.bar_width, tostring(box.time_w), table.concat(parts, ','))
end

-- render(name, data)
-- data: array of { label, time, fraction }, top row first. Rows beyond
-- the data are hidden. Nothing is drawn while the display is hidden.
function M.render(name, data)
    local box = boxes[name]
    local count = visible and #data or 0

    -- Pass 1: create rows, set their text and measure it. Text is measured
    -- once shown, since a hidden object may not report a size.
    for i = 1, count do
        local row = box.rows[i]
        if not row then
            row = make_row()
            box.rows[i] = row
        end
        local d = data[i]
        local label = d.label:sub(1, MAX_LABEL_CHARS)

        if row.name_text ~= label then
            row.name:text(label)
            row.name_text = label
        end
        if row.time_text ~= d.time then
            row.time:text(d.time)
            row.time_text = d.time
        end
        set_row_visible(row, true)

        -- Measured every render, not cached: a size read right after the text
        -- changes can be one frame stale, and the next render corrects it.
        row.name_w = row.name:extents()
        box.time_w = math.max(box.time_w, (row.time:extents()))
    end
    fit_width(box, count)

    -- Pass 2: place and size everything at the settled width.
    local height = fill_height()
    for i = 1, count do
        local row = box.rows[i]
        local d = data[i]

        place_row(box, row, i - 1)

        if row.track_width ~= box.width then
            row.track:size(box.width, height)
            row.track_width = box.width
        end
        local width = math.max(1, math.floor(box.width * d.fraction + 0.5))
        if row.fill_width ~= width then
            row.fill:size(width, height)
            row.fill_width = width
        end
        local r, g, b = fade(1 - d.fraction)
        local color = r * 65536 + g * 256 + b
        if row.color ~= color then
            row.fill:color(r, g, b)
            row.color = color
        end
    end

    for i = count + 1, #box.rows do
        set_row_visible(box.rows[i], false)
    end
    box.shown = count
    update_panel(box)
end

function M.destroy()
    for _, box in pairs(boxes) do
        for _, row in ipairs(box.rows) do
            destroy_row(row)
        end
        box.rows = {}
        box.shown = 0
        destroy_panel(box)
    end
end

-- hit(box, x, y): is the point inside the box as drawn, panel included?
local function hit(box, x, y)
    if box.shown == 0 then
        return false
    end
    local px, py, pw, ph = panel_rect(box)
    return x >= px and x <= px + pw and y >= py and y <= py + ph
end

-- Mouse: kind 0 = move, 1 = left button down, 2 = left button up. Returning
-- true swallows the event so a drag does not also click the game world.
windower.register_event('mouse', function(kind, x, y, delta, blocked)
    if blocked then
        return false
    end
    if kind == 1 then
        for _, box in pairs(boxes) do
            if hit(box, x, y) then
                drag = { box = box, dx = x - box.x, dy = y - box.y, moved = false }
                return true
            end
        end
    elseif kind == 0 then
        if drag then
            drag.box.x = x - drag.dx
            drag.box.y = y - drag.dy
            drag.moved = true
            reposition(drag.box)
            return true
        end
    elseif kind == 2 then
        if drag then
            local finished = drag
            drag = nil
            if finished.moved and on_moved then
                on_moved(finished.box.name, finished.box.x, finished.box.y)
            end
            return true
        end
    end
    return false
end)

return M
