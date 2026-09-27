---------------------------------------------------
-- abilities_cooldown: saved display state
-- Machine-written state (box positions, shown/hidden) in data/state.json.
-- Kept apart from profiles.lua on purpose: the addon rewrites this file, so
-- it must never share a file with hand-written, commented config.
--
-- The file has one fixed shape, so it is written by hand and read with
-- patterns instead of pulling in a general JSON parser:
--   { "visible": true,
--     "boxes": { "main": {"x": 1157, "y": 88}, "sub": {"x": 1007, "y": 88} } }
---------------------------------------------------
local M = {}

local BOX_NAMES = { 'main', 'sub' }

-- Sub box left of the main box, side by side.
local function default_state()
    return {
        visible = true,
        boxes = {
            main = { x = 1157, y = 88 },
            sub  = { x = 1007, y = 88 },
        },
    }
end

M.defaults = default_state

local function state_path()
    return windower.addon_path .. 'data/state.json'
end

-- load()
-- Returns the saved state, filling anything missing or unreadable with the
-- defaults. A missing file is normal on first run.
function M.load()
    local state = default_state()
    local file = io.open(state_path(), 'r')
    if not file then
        return state
    end
    local text = file:read('*a')
    file:close()
    if not text then
        return state
    end

    local visible = text:match('"visible"%s*:%s*(%a+)')
    if visible == 'true' then
        state.visible = true
    elseif visible == 'false' then
        state.visible = false
    end

    for _, name in ipairs(BOX_NAMES) do
        local x, y = text:match('"' .. name .. '"%s*:%s*{%s*"x"%s*:%s*(%-?%d+%.?%d*)%s*,%s*"y"%s*:%s*(%-?%d+%.?%d*)')
        x, y = tonumber(x), tonumber(y)
        if x and y then
            state.boxes[name] = { x = x, y = y }
        end
    end

    return state
end

-- save(state)
-- Returns true, or false plus the reason (for a read-only install folder).
function M.save(state)
    local file, err = io.open(state_path(), 'w')
    if not file then
        return false, err
    end
    local function whole(v)
        return string.format('%d', math.floor(v + 0.5))
    end
    file:write('{\n')
    file:write('  "visible": ', state.visible and 'true' or 'false', ',\n')
    file:write('  "boxes": {\n')
    file:write('    "main": {"x": ', whole(state.boxes.main.x), ', "y": ', whole(state.boxes.main.y), '},\n')
    file:write('    "sub": {"x": ', whole(state.boxes.sub.x), ', "y": ', whole(state.boxes.sub.y), '}\n')
    file:write('  }\n')
    file:write('}\n')
    file:close()
    return true
end

return M
