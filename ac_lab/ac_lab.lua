---------------------------------------------------
-- ac_lab
-- A style lab for abilities_cooldown. Draws a grid of panels, one per bar
-- style, each with two fake cooldowns that keep cycling from red or yellow
-- (just used) to green (ready). Nothing here reads the game; it exists to
-- compare looks and cost before changing the real addon's view.
--
-- A development tool: players only need abilities_cooldown. Deploy it with
-- scripts/deploy-lab-to-windower.sh.
--
-- Load:     //lua load ac_lab
-- Commands: //ac_lab help
---------------------------------------------------
_addon.name     = 'AC Lab'
_addon.author   = 'Mengano'
_addon.version  = '0.0.1'
_addon.commands = { 'ac_lab' }

local texts  = require('texts')
local images = require('images')
local colors = require('lab_colors')
local styles = require('lab_styles')

local COLOR_INFO = 207

-- Fake recasts are picked at random from this range, in seconds.
local MIN_RECAST, MAX_RECAST = 6, 20

-- How long a row stays at "READY" before it starts a new cycle.
local READY_SECONDS = 1.5

local TITLE_H     = 18
local ROW_GAP     = 4
local PANEL_GAP_X = 24
local PANEL_GAP_Y = 14

-- The backdrop behind each panel's rows matches the addon's default panel
-- (ac_config.lua / ac_view.lua): a dark gradient of solid bands.
local BACKDROP_TOP    = { 30, 30, 30 }
local BACKDROP_BOTTOM = { 90, 90, 90 }
local BACKDROP_ALPHA  = 200
local BACKDROP_BANDS  = 32
local BACKDROP_PAD_X, BACKDROP_PAD_TOP, BACKDROP_PAD_BOTTOM = 8, 8, 6

local LABELS = {
    'Hasso', 'Meditate', 'Sekkanoki', 'Third Eye', 'Last Resort', 'Souleater',
    'Arcane Circle', 'Weapon Bash', 'Elemental Seal', 'Manawell', 'Provoke',
    'Berserk', 'Aggressor', 'Warcry', 'Stoneskin', 'Haste', 'Refresh',
    'Utsusemi: Ni', 'Sublimation', 'Convert',
}

local opts = {
    x = 100, y = 160,
    bar_w = 160, bar_h = 22,
    columns = 3,
    mode = 'hsv',
    speed = 1,
    only = nil,              -- nil for all, an index into styles.list, or a name prefix
    backdrop = true,         -- the addon's dark panel behind each style's rows
    font = 'Arial', font_size = 11,
}

local visible = true
local header
local panels = {}
local last_clock

local function say(message)
    windower.add_to_chat(COLOR_INFO, '[ac_lab] ' .. message)
end

local function new_sim()
    return {
        label   = LABELS[math.random(#LABELS)],
        max     = math.random(MIN_RECAST, MAX_RECAST),
        elapsed = 0,
    }
end

local function label_text(x, y, size)
    local t = texts.new('', {
        pos   = { x = x, y = y },
        bg    = { visible = false },
        flags = { draggable = false },
        text  = { size = size, font = opts.font, alpha = 255, red = 220, green = 220, blue = 220,
                  stroke = { width = 2, alpha = 255, red = 0, green = 0, blue = 0 } },
        padding = 0,
    })
    t:show()
    return t
end

local function header_line()
    return string.format('AC Lab   %s -> green, %s (%s)   speed: %sx   //ac_lab help',
        colors.start_name, opts.mode, colors.DESCRIPTIONS[opts.mode], tostring(opts.speed))
end

local function teardown()
    for _, panel in ipairs(panels) do
        panel.title:destroy()
        for _, band in ipairs(panel.backdrop) do
            band:destroy()
        end
        for _, r in ipairs(panel.rows) do
            r.view.destroy()
        end
    end
    panels = {}
    if header then
        header:destroy()
        header = nil
    end
end

local function build()
    teardown()
    if not visible then
        return
    end
    header = label_text(opts.x, opts.y - 24, 10)
    header:text(header_line())

    local indexes = {}
    for i, style in ipairs(styles.list) do
        if opts.only == nil or opts.only == i
            or (type(opts.only) == 'string' and style.name:sub(1, #opts.only) == opts.only) then
            indexes[#indexes + 1] = i
        end
    end
    if #indexes == 0 then
        say('no style matches "' .. tostring(opts.only) .. '"; try //ac_lab only all')
    end

    local panel_h = TITLE_H + 2 * (opts.bar_h + ROW_GAP) + PANEL_GAP_Y
    for n, index in ipairs(indexes) do
        local style = styles.list[index]
        local col = (n - 1) % opts.columns
        local line = math.floor((n - 1) / opts.columns)
        local px = opts.x + col * (opts.bar_w + PANEL_GAP_X)
        local py = opts.y + line * panel_h

        local panel = { index = index, style = style, rows = {}, backdrop = {} }
        if opts.backdrop then
            -- Created before the rows so it draws underneath them.
            local x = px - BACKDROP_PAD_X
            local y = py + TITLE_H - BACKDROP_PAD_TOP
            local w = opts.bar_w + 2 * BACKDROP_PAD_X
            local h = 2 * opts.bar_h + ROW_GAP + BACKDROP_PAD_TOP + BACKDROP_PAD_BOTTOM
            for i = 1, BACKDROP_BANDS do
                local y0 = y + math.floor(h * (i - 1) / BACKDROP_BANDS)
                local y1 = y + math.floor(h * i / BACKDROP_BANDS)
                if y1 > y0 then
                    local t = (i - 0.5) / BACKDROP_BANDS
                    local g = math.floor(BACKDROP_TOP[1] + (BACKDROP_BOTTOM[1] - BACKDROP_TOP[1]) * t + 0.5)
                    local band = images.new({
                        pos       = { x = x, y = y0 },
                        color     = { alpha = BACKDROP_ALPHA, red = g, green = g, blue = g },
                        size      = { width = w, height = y1 - y0 },
                        texture   = { path = '', fit = false },
                        draggable = false,
                    })
                    band:show()
                    panel.backdrop[#panel.backdrop + 1] = band
                end
            end
        end
        panel.title = label_text(px, py, 9)
        for r = 1, 2 do
            local ctx = {
                x = px, y = py + TITLE_H + (r - 1) * (opts.bar_h + ROW_GAP),
                w = opts.bar_w, h = opts.bar_h,
                font = opts.font, font_size = opts.font_size,
            }
            panel.rows[r] = { view = style.new(ctx), sim = new_sim() }
        end
        panel.title:text(string.format('%d %s  (%d objects/row)', index, style.name, panel.rows[1].view.objects))
        panels[#panels + 1] = panel
    end
end

-- state_for(sim, now): the per-frame state every style takes.
local function state_for(sim, now)
    local remaining = sim.max - sim.elapsed
    local ready = remaining <= 0
    local progress = ready and 1 or sim.elapsed / sim.max
    return {
        label     = sim.label,
        time      = ready and 'READY' or tostring(math.ceil(remaining)),
        fraction  = ready and 0 or remaining / sim.max,
        progress  = progress,
        color     = ready and colors.GREEN or colors.blend(opts.mode, progress, remaining),
        remaining = math.max(0, remaining),
        ready     = ready,
        now       = now,
    }
end

-- bench(): times each style's update in a tight loop with values that change
-- every call, so no cached setter can skip work. This measures the Lua side
-- plus the calls into Windower, not the GPU cost of drawing (which tracks the
-- object count shown in each panel title).
local function bench()
    local ITERATIONS = 2000
    say(string.format('benchmark: %d updates per style', ITERATIONS))
    for _, panel in ipairs(panels) do
        local view = panel.rows[1].view
        local sim = { label = 'Bench', max = ITERATIONS, elapsed = 0 }
        local start = os.clock()
        for i = 1, ITERATIONS do
            sim.elapsed = i - 1
            sim.label = (i % 2 == 0) and 'Bench' or 'Bench!'
            view.update(state_for(sim, start + i / 60))
        end
        local spent = os.clock() - start
        say(string.format('  %-13s %3d objects  %7.1f us/update', panel.style.name, view.objects,
            spent / ITERATIONS * 1e6))
    end
end

local HELP = {
    'AC Lab commands (//ac_lab ...):',
    '  from <red|yellow>          the start color',
    '  mode <rgb|hsv|ease|step>   how the start color turns into green',
    '  speed <n>                  cycle speed multiplier (e.g. 0.5, 2)',
    '  only <n|name|all>          one style by number, every style whose name',
    '                             starts with name (e.g. under), or all',
    '  backdrop <on|off>          the addon\'s dark panel behind the rows',
    '  size <width> <height>      bar size in pixels',
    '  pos <x> <y>                top-left of the grid',
    '  columns <n>                panels per line',
    '  font <size>                text size',
    '  bench                      time each style\'s update',
    '  show | hide',
}

local function list_styles()
    for i, s in ipairs(styles.list) do
        say(string.format('  %2d %-13s %s', i, s.name, s.desc))
    end
end

windower.register_event('addon command', function(command, ...)
    command = (command or 'help'):lower()
    local args = { ... }
    local n1, n2 = tonumber(args[1]), tonumber(args[2])

    if command == 'from' and colors.set_start(args[1] or '') then
        if header then header:text(header_line()) end
    elseif command == 'mode' and colors.DESCRIPTIONS[args[1] or ''] then
        opts.mode = args[1]
        if header then header:text(header_line()) end
    elseif command == 'speed' and n1 and n1 > 0 then
        opts.speed = n1
        if header then header:text(header_line()) end
    elseif command == 'only' and args[1] == 'all' then
        opts.only = nil
        build()
    elseif command == 'only' and n1 and styles.list[n1] then
        opts.only = n1
        build()
    elseif command == 'only' and args[1] then
        opts.only = args[1]:lower()
        build()
    elseif command == 'size' and n1 and n2 and n1 >= 40 and n2 >= 4 then
        opts.bar_w, opts.bar_h = n1, n2
        build()
    elseif command == 'pos' and n1 and n2 then
        opts.x, opts.y = n1, n2
        build()
    elseif command == 'columns' and n1 and n1 >= 1 then
        opts.columns = math.floor(n1)
        build()
    elseif command == 'font' and n1 and n1 >= 6 then
        opts.font_size = n1
        build()
    elseif command == 'backdrop' and (args[1] == 'on' or args[1] == 'off') then
        opts.backdrop = args[1] == 'on'
        build()
    elseif command == 'bench' then
        bench()
    elseif command == 'show' then
        visible = true
        build()
    elseif command == 'hide' then
        visible = false
        build()
    else
        for _, line in ipairs(HELP) do
            say(line)
        end
        say('Styles:')
        list_styles()
    end
end)

windower.register_event('prerender', function()
    local now = os.clock()
    local dt = last_clock and math.min(now - last_clock, 0.25) or 0
    last_clock = now
    for _, panel in ipairs(panels) do
        for _, r in ipairs(panel.rows) do
            local sim = r.sim
            sim.elapsed = sim.elapsed + dt * opts.speed
            if sim.elapsed >= sim.max + READY_SECONDS then
                r.sim = new_sim()
                sim = r.sim
            end
            r.view.update(state_for(sim, now))
        end
    end
end)

windower.register_event('unload', teardown)

math.randomseed(os.time())
build()
