local HudElementsDefinitions = require('scripts/ui/hud/hud_elements_player')

local mod = get_mod('better_buff_management')
mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/utilities/table')
mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/utilities/mod')
local HudElementBuffBar = mod:io_dofile(
'better_buff_management/scripts/mods/better_buff_management/hud/hud_element_buff_bar')
local HudElementBuffObserver = mod:io_dofile(
'better_buff_management/scripts/mods/better_buff_management/hud/hud_element_buff_observer')
local BarConfig = mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/models/bar_config')
local management_window = mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/ui/window'):new()

local BUFFS_DATA_SETTING_ID = 'buffs_data'
local BUFFS_CATALOG_SETTING_ID = 'buffs_catalog'
local BARS_SETTING_ID = 'bars'
local TOGGLE_DEFAULT_BAR_SETTING_ID = 'toggle_default_bar'
local LEAVE_DEFAULT_BAR_ALONE_SETTING_ID = 'leave_default_bar_alone'
local GROUP_BUFFS_IN_CATEGORIES_SETTING_ID = 'group_buffs_in_categories'
local RECENT_BUFFS_SETTING_ID = 'recent_buffs'
local ENABLE_RECENT_BUFF_OBSERVER_SETTING_ID = 'enable_recent_buff_observer'
local MAX_RECENT_BUFFS = 50

local HUD_ELEMENT_PLAYER_BUFFS = 'HudElementPlayerBuffs'
local HUD_ELEMENT_BUFF_OBSERVER = 'HudElementBuffObserver'
local _, PlayerBuffsDefinition = table.find_by_key(HudElementsDefinitions, 'class_name', HUD_ELEMENT_PLAYER_BUFFS)

-- -------------------------------
-- ------- Local Functions -------
-- -------------------------------

local function recreate_hud()
    local ui_manager = Managers.ui
    if ui_manager then
        local hud = ui_manager._hud
        if hud then
            local player_manager = Managers.player
            local player = player_manager:local_player(1)
            local peer_id = player:peer_id()
            local local_player_id = player:local_player_id()
            local elements = hud._element_definitions
            local visibility_groups = hud._visibility_groups

            ui_manager:destroy_player_hud()
            ui_manager:create_player_hud(peer_id, local_player_id, elements, visibility_groups)
        end
    end
end

-- Exposed so the config window can re-bake bars on ANY user close (imgui [X] or
-- ESC), not only the keybind toggle -- otherwise position/direction/order/buff-
-- assignment edits silently don't apply until the next keybind close. Only call
-- this from in-mission, player-bound paths (recreate_hud calls local_player(1),
-- which C-crashes with no human players); never from on_game_state_changed.
mod.recreate_buff_hud = recreate_hud

local function remove_buff_bar_hud_definitions(definitions)
    repeat
        local index = table.index_of_condition(definitions, function(definition)
            return definition.class_name:starts_with('HudElementBuffBar')
        end)

        if index > 0 then
            table.remove(definitions, index)
        end
    until index == -1
end

local function remove_buff_observer_hud_definition(definitions)
    repeat
        local index = table.index_of_condition(definitions, function(definition)
            return definition.class_name == HUD_ELEMENT_BUFF_OBSERVER
        end)

        if index > 0 then
            table.remove(definitions, index)
        end
    until index == -1
end

local function add_buff_observer_hud_definition(definitions)
    if not mod:get(ENABLE_RECENT_BUFF_OBSERVER_SETTING_ID) then
        return
    end

    local index = table.index_of_condition(definitions, function(definition)
        return definition.class_name == HUD_ELEMENT_BUFF_OBSERVER
    end)

    if index <= 0 then
        table.insert(definitions, {
            package = 'packages/ui/hud/player_buffs/player_buffs',
            use_retained_mode = true,
            use_hud_scale = true,
            class_name = HUD_ELEMENT_BUFF_OBSERVER,
            filename = 'better_buff_management/scripts/mods/better_buff_management/hud/hud_element_buff_observer',
            visibility_groups = {
                'dead',
                'alive',
                'communication_wheel'
            }
        })
    end
end

local function get_filter_for_bar(buffs_data, bar_name)
    if table.is_nil_or_empty(buffs_data) then
        return nil
    end

    local filter_data = {}
    local has_entries = false

    for _, data in pairs(buffs_data) do
        if data.bar_name == bar_name and not data.is_hidden then
            filter_data[data.name] = true
            has_entries = true
        end
    end

    if not has_entries then
        return nil
    end

    return filter_data
end

-- Fixed slot order for the bar's 'preserved' order mode: assign each assigned,
-- non-hidden buff a stable 1..n index by alphabetical name -- the same order the
-- imgui config window lists them in. The HUD element uses this to keep buffs in a
-- stable relative order (see HudElementBuffBar:_update_buff_alignments).
local function build_order_index_for_bar(buffs_data, bar_name)
    if table.is_nil_or_empty(buffs_data) then
        return nil
    end

    local names = {}
    local count = 0
    for _, data in pairs(buffs_data) do
        if data.bar_name == bar_name and not data.is_hidden then
            count = count + 1
            names[count] = data.name
        end
    end

    if count == 0 then
        return nil
    end

    table.sort(names, function(a, b)
        return (a or '') < (b or '')
    end)

    local order_index = {}
    for i = 1, count do
        order_index[names[i]] = i
    end

    return order_index
end

local function add_buff_bar_hud_definitions(definitions)
    local buffs_data = mod:get(BUFFS_DATA_SETTING_ID)
    local bars = mod:get(BARS_SETTING_ID)

    if not table.is_nil_or_empty(buffs_data) and not table.is_nil_or_empty(bars) then
        for _, bar_name in ipairs(bars) do
            -- Per-bar position/direction/order, baked at HUD-creation time. Edits
            -- in the config window take effect on the next recreate_hud (window
            -- close), same as buff-to-bar assignment changes.
            local bar_config = BarConfig.get(bar_name)
            bar_config.order_index = build_order_index_for_bar(buffs_data, bar_name)

            table.insert(definitions, {
                package = 'packages/ui/hud/player_buffs/player_buffs',
                use_retained_mode = true,
                use_hud_scale = true,
                class_name = ('%s_%s'):format('HudElementBuffBar', string.to_pascal_case(bar_name)),
                filename = 'better_buff_management/scripts/mods/better_buff_management/hud/hud_element_buff_bar',
                visibility_groups = {
                    'dead',
                    'alive',
                    'communication_wheel'
                },
                buffs_filter = get_filter_for_bar(buffs_data, bar_name),
                bar_config = bar_config
            })
        end
    end
end

local function add_or_remove_default_buff_bar(definitions)
    local index = table.index_of_condition(definitions, function(definition)
        return definition.class_name == HUD_ELEMENT_PLAYER_BUFFS
    end)

    -- Hands-off: keep the vanilla bar present and never remove it, overriding
    -- the toggle below. The element list reaching this hook is the canonical
    -- hud_elements_player table (or a cached clone of it), so a previous
    -- "toggle off" session may have removed the bar -- re-add it if missing to
    -- restore HudElementPlayerBuffs to its default state.
    if mod:get(LEAVE_DEFAULT_BAR_ALONE_SETTING_ID) then
        if index <= 0 then
            table.insert(definitions, PlayerBuffsDefinition)
        end
        return
    end

    if mod:get(TOGGLE_DEFAULT_BAR_SETTING_ID) then
        if index > 0 then
            table.remove(definitions, index)
        end
    elseif not mod:is_in_hub() then
        if index <= 0 then
            table.insert(definitions, PlayerBuffsDefinition)
        end
    end
end

-- -------------------------------
-- ------- Public Functions ------
-- -------------------------------

mod._recent_buffs = mod:get(RECENT_BUFFS_SETTING_ID) or {}
mod._recent_buffs_dirty = false
mod._next_recent_buffs_flush_t = 0
mod._recent_buffs_revision = 0
mod._buffs_data_revision = 0

mod.get_recent_buffs = function()
    return mod._recent_buffs or {}
end

mod.get_recent_buffs_revision = function()
    return mod._recent_buffs_revision or 0
end

mod.get_buffs_data_revision = function()
    return mod._buffs_data_revision or 0
end

mod.bump_buffs_data_revision = function()
    mod._buffs_data_revision = (mod._buffs_data_revision or 0) + 1
end

mod.clear_recent_buffs = function()
    mod._recent_buffs = {}
    mod._recent_buffs_dirty = false
    mod._next_recent_buffs_flush_t = 0
    mod._recent_buffs_revision = (mod._recent_buffs_revision or 0) + 1
    mod:set(RECENT_BUFFS_SETTING_ID, {})
end

mod.record_recent_buff = function(_, buff_name)
    if type(buff_name) ~= 'string' or buff_name == '' then
        return
    end

    local recent_buffs = mod._recent_buffs
    if type(recent_buffs) ~= 'table' then
        recent_buffs = {}
        mod._recent_buffs = recent_buffs
    end

    local existing_index = table.index_of(recent_buffs, buff_name)
    if existing_index == 1 then
        return
    end

    if existing_index and existing_index > 0 then
        table.remove(recent_buffs, existing_index)
    end

    table.insert(recent_buffs, 1, buff_name)

    while #recent_buffs > MAX_RECENT_BUFFS do
        table.remove(recent_buffs)
    end

    mod._recent_buffs_dirty = true
    mod._recent_buffs_revision = (mod._recent_buffs_revision or 0) + 1
end

mod.configure_buffs = function()
    if management_window.is_open then
        management_window:close()
        recreate_hud()
    elseif not mod:is_in_hub() then
        recreate_hud()
        management_window:open()
    end
end

mod.reindex_buffs_catalog = function()
    if management_window and management_window.reindex_catalog then
        management_window:reindex_catalog()
    end
end

mod.clear_buffs_catalog = function()
    mod:set(BUFFS_CATALOG_SETTING_ID, {})

    if management_window and management_window.invalidate_catalog_cache then
        management_window:invalidate_catalog_cache()
    end
end

mod.on_setting_changed = function(setting_id)
    if setting_id == TOGGLE_DEFAULT_BAR_SETTING_ID
        or setting_id == ENABLE_RECENT_BUFF_OBSERVER_SETTING_ID
        or setting_id == LEAVE_DEFAULT_BAR_ALONE_SETTING_ID
        or setting_id == GROUP_BUFFS_IN_CATEGORIES_SETTING_ID then
        recreate_hud()
    end
end

-- utilities/mod.lua already defines on_game_state_changed (invalidates the
-- is_in_hub cache). Chain it: also force the configure window closed on every
-- state transition so its open/cursor/imgui state can never get stuck and
-- freeze input (e.g. leaving/re-entering the Psykhanium with it open).
local _prev_on_game_state_changed = mod.on_game_state_changed
mod.on_game_state_changed = function(status, state_name)
    if _prev_on_game_state_changed then
        _prev_on_game_state_changed(status, state_name)
    end

    if management_window.is_open then
        management_window:close()
    end
end

mod.update = function(dt)
    if mod._recent_buffs_dirty then
        local t = 0
        if Managers.time then
            t = Managers.time:time('main') or 0
        end

        if t >= (mod._next_recent_buffs_flush_t or 0) then
            mod:set(RECENT_BUFFS_SETTING_ID, mod._recent_buffs or {})
            mod._recent_buffs_dirty = false
            mod._next_recent_buffs_flush_t = t + 2
        end
    end

    management_window:update()
end

-- -- -------------------------------
-- -- ------------ Hooks ------------
-- -- -------------------------------

mod:hook('UIManager', 'using_input', function(func, ...)
    return management_window.is_open or func(...)
end)

mod:hook('UIHud', 'init', function(func, self, definitions, visibility_groups, params)
    add_or_remove_default_buff_bar(definitions)

    remove_buff_bar_hud_definitions(definitions)
    remove_buff_observer_hud_definition(definitions)
    add_buff_bar_hud_definitions(definitions)
    add_buff_observer_hud_definition(definitions)

    return func(self, definitions, visibility_groups, params)
end)

mod:hook('UIHud', '_add_element', function(func, self, definition, elements, elements_array)
    if definition.class_name:starts_with('HudElementBuffBar') then
        local draw_layer = 0
        local hud_scale = definition.use_hud_scale and (self._hud_scale ~= nil and self:_hud_scale()) or
        RESOLUTION_LOOKUP.scale
        local hud_element = HudElementBuffBar:new(self, draw_layer, hud_scale, definition.buffs_filter,
            definition.bar_config)
        hud_element.__class_name = definition.class_name
        elements[definition.class_name] = hud_element
        table.insert(elements_array, hud_element)
    elseif definition.class_name == HUD_ELEMENT_BUFF_OBSERVER then
        local draw_layer = 0
        local hud_scale = definition.use_hud_scale and (self._hud_scale ~= nil and self:_hud_scale()) or
        RESOLUTION_LOOKUP.scale
        local hud_element = HudElementBuffObserver:new(self, draw_layer, hud_scale)
        hud_element.__class_name = definition.class_name
        elements[definition.class_name] = hud_element
        table.insert(elements_array, hud_element)
    else
        func(self, definition, elements, elements_array)
    end
end)

local function resolve_recent_buff_name(buff_instance)
    if buff_instance == nil then
        return nil
    end
    -- Reuse cache flag set by hud_element_buff_bar resolver (shared field).
    local cached = buff_instance._bbm_template_name
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local buff_template = nil
    if type(buff_instance.template) == 'function' then
        buff_template = buff_instance:template()
    end

    local template_name = buff_template and buff_template.name or nil

    if type(template_name) ~= 'string' or template_name == '' then
        template_name = buff_instance._template_name
    end

    if (type(template_name) ~= 'string' or template_name == '') and type(buff_instance.template_name) == 'function' then
        template_name = buff_instance:template_name()
    end

    if type(template_name) ~= 'string' or template_name == '' then
        buff_instance._bbm_template_name = false
        return nil
    end

    buff_instance._bbm_template_name = template_name
    return template_name
end

local function record_buff_instance(buff_instance)
    if buff_instance == nil or buff_instance._bbm_recent_recorded then
        return
    end

    local template_name = resolve_recent_buff_name(buff_instance)
    if template_name then
        mod:record_recent_buff(template_name)
        buff_instance._bbm_recent_recorded = true
    end
end

mod:hook_safe('HudElementPlayerBuffs', 'event_player_buff_added', function(self, player, buff_instance)
    record_buff_instance(buff_instance)
end)

mod:hook_safe('HudElementPlayerBuffs', '_sync_current_active_buffs', function(self, buffs)
    if type(buffs) ~= 'table' then
        return
    end

    for i = 1, #buffs do
        record_buff_instance(buffs[i])
    end
end)
