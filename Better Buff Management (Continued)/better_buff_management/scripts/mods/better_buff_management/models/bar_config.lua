local mod = get_mod('better_buff_management')

local ArchetypeSettings = require('scripts/settings/archetype/archetype_settings')

-- Per-bar configuration (position, growth direction, order mode). Stored under a
-- single 'bar_configs' setting as a map keyed by bar name, kept separate from the
-- 'bars' name array so existing saves stay backward compatible (missing entries
-- just fall back to defaults via normalize()).
local BAR_CONFIGS_SETTING_ID = 'bar_configs'

local BarConfig = {}

BarConfig.SETTING_ID = BAR_CONFIGS_SETTING_ID

-- Playable classes (archetypes) a bar can be restricted to, sourced from the
-- engine so future classes appear automatically. Ordered by the game's class-
-- selection order (veteran, zealot, psyker, ogryn, adamant, ...). Internal
-- archetype names are stable save keys; label lookup is class_label_<name>.
local function _build_class_names()
    local order = ArchetypeSettings.archetype_ui_selection_order
    local names = {}
    for name in pairs(ArchetypeSettings.archetype_names) do
        names[#names + 1] = name
    end
    table.sort(names, function(a, b)
        local oa = (order and order[a]) or math.huge
        local ob = (order and order[b]) or math.huge
        if oa == ob then
            return a < b
        end
        return oa < ob
    end)
    return names
end

BarConfig.CLASS_NAMES = _build_class_names()

local _valid_class = {}
for i = 1, #BarConfig.CLASS_NAMES do
    _valid_class[BarConfig.CLASS_NAMES[i]] = true
end

-- Growth directions. The value strings are stable save keys AND the suffix of the
-- localization ids (buff_direction_option_<value>), so don't rename them lightly.
-- 'center' = horizontal, but the row stays centered on the bar's anchor (grows
-- both ways as buffs are added). Append new directions at the end so existing
-- saved indices in the imgui combo don't shift.
BarConfig.DIRECTIONS = { 'left_right', 'right_left', 'top_bottom', 'bottom_top', 'center' }
BarConfig.DEFAULT_DIRECTION = 'left_right'

-- Order modes. 'activation' = vanilla activated_time order (buffs shift as they
-- re-trigger). 'preserved' = stable relative order by the bar's config order,
-- gaps collapsed (active buffs pack toward the origin, order never shuffles).
BarConfig.ORDER_MODES = { 'activation', 'preserved' }
BarConfig.DEFAULT_ORDER_MODE = 'activation'

-- Approx top-left workspace position of the vanilla default buff bar. Its
-- background is left/bottom anchored at {550, -50} in the 1080-tall UI workspace
-- with height 80 -> top edge ~= 1080 - 50 - 80 = 950. Custom bars are top-left
-- anchored, so this is the equivalent top-left coordinate. Resolution independent
-- (scenegraph positions are pre-scale workspace units).
BarConfig.DEFAULT_SNAP_POS = { 550, 950 }

local function _index_of(list, value)
    for i = 1, #list do
        if list[i] == value then
            return i
        end
    end
    return nil
end

-- Buff opacity multiplier (0-1). 1 = fully opaque (default / vanilla look).
BarConfig.DEFAULT_OPACITY = 1

local function _clamp01(v)
    if v < 0 then
        return 0
    elseif v > 1 then
        return 1
    end
    return v
end

-- Normalize a raw per-bar class restriction into either nil (show on ALL classes
-- -- the default, and future-proof: new classes are included automatically) or a
-- map { archetype_name = true } of the enabled classes. An explicit empty map is
-- preserved (bar shows on NO class). Unknown keys are dropped; a set covering every
-- known class collapses to nil so it keeps meaning "all" as classes are added.
function BarConfig.normalize_classes(raw_classes)
    if type(raw_classes) ~= 'table' then
        return nil
    end

    local set = {}
    local count = 0
    for name, enabled in pairs(raw_classes) do
        if enabled and _valid_class[name] then
            set[name] = true
            count = count + 1
        end
    end

    if count == 0 then
        return {}
    end

    if count >= #BarConfig.CLASS_NAMES then
        return nil
    end

    return set
end

-- Normalize a raw saved config (or nil) into a full table with valid defaults.
function BarConfig.normalize(raw)
    local pos_x = 0
    local pos_y = 0
    local direction = BarConfig.DEFAULT_DIRECTION
    local order_mode = BarConfig.DEFAULT_ORDER_MODE
    local opacity = BarConfig.DEFAULT_OPACITY
    local classes = nil

    if type(raw) == 'table' then
        pos_x = tonumber(raw.pos_x) or 0
        pos_y = tonumber(raw.pos_y) or 0
        if _index_of(BarConfig.DIRECTIONS, raw.direction) then
            direction = raw.direction
        end
        if _index_of(BarConfig.ORDER_MODES, raw.order_mode) then
            order_mode = raw.order_mode
        end
        opacity = _clamp01(tonumber(raw.opacity) or BarConfig.DEFAULT_OPACITY)
        classes = BarConfig.normalize_classes(raw.classes)
    end

    return {
        pos_x = pos_x,
        pos_y = pos_y,
        direction = direction,
        order_mode = order_mode,
        opacity = opacity,
        classes = classes,
    }
end

function BarConfig.get_all()
    local raw = mod:get(BAR_CONFIGS_SETTING_ID)
    if type(raw) ~= 'table' then
        return {}
    end
    return raw
end

-- Read one bar's config, always normalized (never nil).
function BarConfig.get(bar_name)
    local all = BarConfig.get_all()
    return BarConfig.normalize(all[bar_name])
end

-- True if a bar with this class restriction shows for `archetype_name`. nil
-- restriction = all classes; an empty map = no class.
function BarConfig.class_enabled(classes, archetype_name)
    if classes == nil then
        return true
    end
    return classes[archetype_name] and true or false
end

-- Return a new class-restriction value with `name` toggled on/off. Materializes
-- the current effective set (nil -> all enabled) first, then re-normalizes so an
-- all-enabled result collapses back to nil and an all-disabled result is {}.
function BarConfig.toggle_class(classes, name, on)
    if not _valid_class[name] then
        return classes
    end

    local set = {}
    if classes == nil then
        for i = 1, #BarConfig.CLASS_NAMES do
            set[BarConfig.CLASS_NAMES[i]] = true
        end
    else
        for k, v in pairs(classes) do
            if v then
                set[k] = true
            end
        end
    end

    if on then
        set[name] = true
    else
        set[name] = nil
    end

    return BarConfig.normalize_classes(set)
end

function BarConfig.direction_index(direction)
    return _index_of(BarConfig.DIRECTIONS, direction) or 1
end

function BarConfig.order_mode_index(order_mode)
    return _index_of(BarConfig.ORDER_MODES, order_mode) or 1
end

return BarConfig
