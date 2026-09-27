---------------------------------------------------
-- abilities_cooldown: on-screen boxes
-- Draws the two boxes (main job, sub job). Each row is four objects: an
-- image for the empty bar, an image for the filled part, and two texts (the
-- name on the left, the countdown right-aligned). Rows are pooled and
-- reused; unused ones are just hidden.
--
-- Dragging is handled here, not by the texts/images libraries: their built-in
-- drag moves one object at a time, which would tear a row apart. Every object
-- is created non-draggable, and one mouse handler moves a whole box.
--
-- Usage:
--   local view = require('ac_view')
--   view.init(settings, state.boxes, function(name, x, y) ... end)
--   view.render('main', { { label = 'Hasso', time = '42', fraction = 0.7, warn = false } })
---------------------------------------------------
local texts  = require('texts')
local images = require('images')

local M = {}

-- Horizontal gap between the bar's edge and its text.
local TEXT_PAD = 4

local settings
local boxes = {}
local visible = true
local on_moved
local drag

local function new_box(name, position)
    return { name = name, x = position.x, y = position.y, rows = {}, shown = 0 }
end

-- make_bar(color, alpha)
-- A solid rectangle: an image with no texture. Starts hidden.
local function make_bar(color, alpha)
    return images.new({
        pos       = { x = 0, y = 0 },
        color     = { alpha = alpha, red = color[1], green = color[2], blue = color[3] },
        size      = { width = settings.bar_width, height = settings.bar_height },
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
    row.track = make_bar(settings.colors.track, settings.bg_alpha)
    row.fill  = make_bar(settings.colors.bar, settings.bar_alpha)
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
    if row.x == x and row.y == y then
        return
    end
    row.x, row.y = x, y
    row.track:pos(x, y)
    row.fill:pos(x, y)
    -- Roughly centers the text vertically in the bar; text_offset_y tunes it.
    local text_y = y + math.floor((settings.bar_height - settings.font_size * 1.5) / 2) + settings.text_offset_y
    row.name:pos(x + TEXT_PAD, text_y)
    row.time:pos(x + settings.bar_width - TEXT_PAD, text_y)
end

local function reposition(box)
    for i = 1, box.shown do
        place_row(box, box.rows[i], i - 1)
    end
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

-- render(name, data)
-- data: array of { label, time, fraction, warn }, top row first. Rows beyond
-- the data are hidden. Nothing is drawn while the display is hidden.
function M.render(name, data)
    local box = boxes[name]
    local count = visible and #data or 0

    for i = 1, count do
        local row = box.rows[i]
        if not row then
            row = make_row()
            box.rows[i] = row
        end
        local d = data[i]

        place_row(box, row, i - 1)

        local width = math.max(1, math.floor(settings.bar_width * d.fraction + 0.5))
        if row.fill_width ~= width then
            row.fill:size(width, settings.bar_height)
            row.fill_width = width
        end
        if row.warn ~= d.warn then
            local c = d.warn and settings.colors.warn or settings.colors.bar
            row.fill:color(c[1], c[2], c[3])
            row.warn = d.warn
        end
        if row.name_text ~= d.label then
            row.name:text(d.label)
            row.name_text = d.label
        end
        if row.time_text ~= d.time then
            row.time:text(d.time)
            row.time_text = d.time
        end
        set_row_visible(row, true)
    end

    for i = count + 1, #box.rows do
        set_row_visible(box.rows[i], false)
    end
    box.shown = count
end

function M.destroy()
    for _, box in pairs(boxes) do
        for _, row in ipairs(box.rows) do
            destroy_row(row)
        end
        box.rows = {}
        box.shown = 0
    end
end

-- hit(box, x, y): is the point inside the rows currently drawn for this box?
local function hit(box, x, y)
    if box.shown == 0 then
        return false
    end
    local step = settings.bar_height + settings.row_spacing
    local top, bottom
    if settings.grow == 'up' then
        top = box.y - (box.shown - 1) * step
        bottom = box.y + settings.bar_height
    else
        top = box.y
        bottom = box.y + (box.shown - 1) * step + settings.bar_height
    end
    return x >= box.x and x <= box.x + settings.bar_width and y >= top and y <= bottom
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
