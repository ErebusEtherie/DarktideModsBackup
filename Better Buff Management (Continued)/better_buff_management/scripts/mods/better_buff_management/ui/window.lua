local mod = get_mod('better_buff_management')
mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/ui/components/base_component')

-- Source Code requires
local BUFF_TEMPLATES = require('scripts/settings/buff/buff_templates')
local MASTER_ITEMS = require('scripts/backend/master_items')
local WEAPON_TRAIT_TEMPLATES = require('scripts/settings/equipment/weapon_traits/weapon_trait_templates')

-- Weapon-trait buffs whose spawning TRAIT is named differently from the buff.
-- A trait's icon lives on its trait master item, keyed by the TRAIT name, but many
-- bespoke traits spawn a buff whose template name differs from the trait key --
-- e.g. trait 'weapon_trait_bespoke_shotpistol_shield_p1_windup_increases_power'
-- ("Pinpointing Target") spawns buff '..._increases_power_while_aiming'. get_icon
-- scans master items by trait name, so a buff whose name doesn't equal its trait
-- key finds no icon and gets dropped from the catalog entirely. Map each buff name
-- to the trait(s) that reference it (WeaponTraitTemplates[trait].buffs is keyed by
-- buff_template_name, exactly as buff.lua resolves overrides) so the scan can match
-- on the trait name too. Skip the buff_name == trait_name case -- already covered.
local BUFF_TO_TRAIT_NAMES = {}
for trait_name, trait_template in pairs(WEAPON_TRAIT_TEMPLATES) do
    if type(trait_template) == 'table' and type(trait_template.buffs) == 'table' then
        for buff_name in pairs(trait_template.buffs) do
            if type(buff_name) == 'string' and buff_name ~= '' and buff_name ~= trait_name then
                local list = BUFF_TO_TRAIT_NAMES[buff_name]
                if not list then
                    list = {}
                    BUFF_TO_TRAIT_NAMES[buff_name] = list
                end
                list[#list + 1] = trait_name
            end
        end
    end
end

local BuffData = mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/models/buff_data')

local SettingsComponent = mod:io_dofile(
    'better_buff_management/scripts/mods/better_buff_management/ui/components/settings_component')
local BuffBarsComponent = mod:io_dofile(
    'better_buff_management/scripts/mods/better_buff_management/ui/components/buff_bars_component')
local SearchComponent = mod:io_dofile(
    'better_buff_management/scripts/mods/better_buff_management/ui/components/search_component')

local MOD_NAME = mod:localize('mod_name')
local CLASS_NAME = 'ManagementWindow'

-- ESC-to-close support. The DMF Imgui wrapper exposes no key-query API, so read
-- the raw Keyboard device like DMF's own keybind system does. Resolve the button
-- index once (it's stable) and guard with pcall -- button_index errors on names
-- the active device doesn't know.
local Keyboard = rawget(_G, 'Keyboard')
local _esc_index = nil
local _esc_index_resolved = false
local function _get_esc_index()
    if _esc_index_resolved then
        return _esc_index
    end
    _esc_index_resolved = true

    if Keyboard and Keyboard.button_index then
        local ok, idx = pcall(Keyboard.button_index, 'esc')
        if ok then
            _esc_index = idx
        end
    end

    return _esc_index
end

local function _esc_pressed()
    if not Keyboard then
        return false
    end

    local index = _get_esc_index()
    if not index then
        return false
    end

    return Keyboard.button(index) > 0
end

local ERROR_PREFIX = ('[%s][%s]'):format(MOD_NAME, CLASS_NAME)
local ERRORS = {
}

local BUFFS_DATA_SETTING_ID = 'buffs_data'
local BUFFS_CATALOG_SETTING_ID = 'buffs_catalog'

-- Configure-window geometry is driven by mod-menu sliders (in-game imgui resize
-- is unstable), applied every frame with no_resize/no_move so it can't drift.
local WINDOW_WIDTH_SETTING_ID = 'configure_window_width'
local WINDOW_HEIGHT_SETTING_ID = 'configure_window_height'
local WINDOW_X_SETTING_ID = 'configure_window_x'
local WINDOW_Y_SETTING_ID = 'configure_window_y'

local function _geom(setting_id, fallback)
    return tonumber(mod:get(setting_id)) or fallback
end

-- -------------------------------
-- ------- Local Functions -------
-- -------------------------------

local function _add_unique_name(candidate_names, value)
    if not value or value == '' then
        return
    end

    for _, existing_value in ipairs(candidate_names) do
        if existing_value == value then
            return
        end
    end

    table.insert(candidate_names, value)
end

local function _get_buff_name_candidates(buff_name)
    local candidate_names = {}

    _add_unique_name(candidate_names, buff_name)
    _add_unique_name(candidate_names, buff_name:gsub('_parent$', ''))
    _add_unique_name(candidate_names, buff_name:gsub('_child$', ''))
    _add_unique_name(candidate_names, buff_name:gsub('_proc$', ''))

    return candidate_names
end

-- Extend a buff's candidate-name list (in place) with the trait names that spawn
-- any of those buff names, so the item scan can match a trait item whose .trait is
-- the trait key rather than the buff name. Deduped via _add_unique_name.
local function _append_trait_candidates(candidate_names)
    local original_count = #candidate_names

    for i = 1, original_count do
        local trait_names = BUFF_TO_TRAIT_NAMES[candidate_names[i]]
        if trait_names then
            for j = 1, #trait_names do
                _add_unique_name(candidate_names, trait_names[j])
            end
        end
    end

    return candidate_names
end

local function _item_has_trait_name(item, candidate_names)
    if type(item) ~= 'table' then
        return false
    end

    for _, candidate_name in ipairs(candidate_names) do
        if item.trait == candidate_name or item.trait_name == candidate_name then
            return true
        end

        if type(item.traits) == 'table' then
            for _, trait in pairs(item.traits) do
                if trait == candidate_name then
                    return true
                end

                if type(trait) == 'table' then
                    if trait.name == candidate_name or trait.id == candidate_name or trait.trait == candidate_name or
                        trait.trait_name == candidate_name then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function _clone_buffs_data(source_buffs_data)
    local cloned_buffs_data = {}

    if table.is_nil_or_empty(source_buffs_data) then
        return cloned_buffs_data
    end

    for name, buff_data in pairs(source_buffs_data) do
        if type(buff_data) == 'table' and not string.is_nil_or_whitespace(buff_data.name or name) then
            cloned_buffs_data[name] = BuffData:new({
                name = buff_data.name or name,
                icon = buff_data.icon,
                is_hidden = buff_data.is_hidden,
                bar_name = buff_data.bar_name
            })
        end
    end

    return cloned_buffs_data
end

local function _create_catalog_entry(buff_data)
    if type(buff_data) ~= 'table' then
        return nil
    end

    if string.is_nil_or_whitespace(buff_data.name) then
        return nil
    end

    if string.is_nil_or_whitespace(buff_data.icon) then
        return nil
    end

    return {
        name = buff_data.name,
        icon = buff_data.icon
    }
end

local function _read_catalog(raw_catalog)
    local catalog = {}

    if table.is_nil_or_empty(raw_catalog) then
        return catalog
    end

    for key, data in pairs(raw_catalog) do
        if type(data) == 'table' then
            local name = data.name or key
            local template = BUFF_TEMPLATES[name]

            if template and not string.is_nil_or_whitespace(data.icon) then
                catalog[name] = BuffData:new({
                    name = name,
                    icon = data.icon
                })
            end
        end
    end

    return catalog
end

local function _overlay_saved_assignments(buffs_data, raw_buffs_data)
    if table.is_nil_or_empty(raw_buffs_data) then
        return
    end

    for key, data in pairs(raw_buffs_data) do
        if type(data) == 'table' and not string.is_nil_or_whitespace(data.name) then
            local template = BUFF_TEMPLATES[data.name]

            if template then
                if buffs_data[data.name] == nil then
                    buffs_data[data.name] = BuffData:new({
                        name = data.name,
                        icon = data.icon
                    })
                end

                buffs_data[data.name].is_hidden = data.is_hidden or false
                buffs_data[data.name].bar_name = data.bar_name
            end
        end
    end
end

local function get_icon(buff_template, cached_items)
    if buff_template.hide_icon_in_hud then
        return nil
    end

    if buff_template.hud_icon then
        return buff_template.hud_icon
    end

    local candidate_names = _get_buff_name_candidates(buff_template.name)

    for _, candidate_name in ipairs(candidate_names) do
        local parent = table.find_by_key(BUFF_TEMPLATES, 'child_buff_template', candidate_name)
        if parent and BUFF_TEMPLATES[parent] and BUFF_TEMPLATES[parent].hud_icon then
            return BUFF_TEMPLATES[parent].hud_icon
        end
    end

    if buff_template.child_buff_template then
        local child_template = table.find_by_key(BUFF_TEMPLATES, 'name', buff_template.child_buff_template)
        if child_template and child_template.hud_icon then
            return child_template.hud_icon
        end
    end

    if type(cached_items) ~= 'table' then
        cached_items = {}
    end

    -- Add trait names that spawn this buff (only needed for the item scan; the
    -- BUFF_TEMPLATES parent/child lookups above key on buff names, not trait keys).
    _append_trait_candidates(candidate_names)

    for _, item in pairs(cached_items) do
        if _item_has_trait_name(item, candidate_names) then
            if item.icon and item.icon ~= '' then
                return item.icon
            end

            if item.hud_icon and item.hud_icon ~= '' then
                return item.hud_icon
            end
        end
    end

    return nil
end


-- -------------------------------
-- --------- Constructor ---------
-- -------------------------------
local ManagementWindow = class(CLASS_NAME, 'BaseComponent')
function ManagementWindow:init()
    ManagementWindow.super.init(self)

    self.is_open = false
    self._cursor_pushed = false
    self._esc_was_down = false
    self._buffs_data = nil
    self._buffs_data_cache_ready = false
    self._catalog_cache = nil
    self._catalog_cache_ready = false

    self._settings_component = nil
    self._buff_bars_component = nil
    self._search_component = nil
end

-- -------------------------------
-- ------ Private Functions ------
-- -------------------------------

function ManagementWindow:_reindex_catalog_data()
    local catalog = {}
    local cached_items = MASTER_ITEMS.get_cached()

    for buff_category, template in pairs(BUFF_TEMPLATES) do
        if not (buff_category == 'PREDICTED' or buff_category == 'NON_PREDICTED') then
            local icon = get_icon(template, cached_items)

            if not string.is_nil_or_whitespace(icon) then
                catalog[template.name] = BuffData:new({
                    name = template.name,
                    icon = icon
                })
            end
        end
    end

    self._catalog_cache = catalog
    self._catalog_cache_ready = true

    local save_catalog = {}
    for name, buff_data in pairs(catalog) do
        local catalog_entry = _create_catalog_entry(buff_data)
        if catalog_entry then
            save_catalog[name] = catalog_entry
        end
    end

    mod:set(BUFFS_CATALOG_SETTING_ID, save_catalog)

    return catalog
end

function ManagementWindow:_load_catalog_data()
    if self._catalog_cache_ready and self._catalog_cache ~= nil then
        return self._catalog_cache
    end

    local raw_catalog = mod:get(BUFFS_CATALOG_SETTING_ID)
    local catalog = _read_catalog(raw_catalog)

    if table.is_nil_or_empty(catalog) then
        catalog = self:_reindex_catalog_data()
    else
        self._catalog_cache = catalog
        self._catalog_cache_ready = true
    end

    return self._catalog_cache or {}
end

function ManagementWindow:_load_buffs_data()
    if self._buffs_data_cache_ready and self._buffs_data ~= nil then
        return
    end

    local buffs_data = _clone_buffs_data(self:_load_catalog_data())
    local raw_buffs_data = mod:get(BUFFS_DATA_SETTING_ID)

    _overlay_saved_assignments(buffs_data, raw_buffs_data)

    self._buffs_data = buffs_data
    self._buffs_data_cache_ready = true
end

function ManagementWindow:_save_buffs_data()
    local save_data = {}

    if table.is_nil_or_empty(self._buffs_data) then
        mod:set(BUFFS_DATA_SETTING_ID, save_data)
        return
    end

    for _, data in pairs(self._buffs_data) do
        if not string.is_nil_or_whitespace(data.bar_name) then
            save_data[data.name] = data:save_data()
        end
    end

    mod:set(BUFFS_DATA_SETTING_ID, save_data)
end

function ManagementWindow:_create_ui_components()
    local settings_widgets = mod:get_internal_data('options').widgets
    self._settings_component = SettingsComponent:new(settings_widgets)
    self._buff_bars_component = BuffBarsComponent:new(self._buffs_data)
    self._search_component = SearchComponent:new(self._buffs_data)
end

function ManagementWindow:_destroy_ui_components()
    self._settings_component = nil
    self._buff_bars_component = nil
    self._search_component = nil
end

-- -------------------------------
-- ------- Public Functions ------
-- -------------------------------

-- Own a cursor whenever the window is open. Track our push with a flag and gate
-- ONLY on that flag -- never on cursor_active(). Gating on cursor_active() means
-- that if another owner (DMF mod menu, comm wheel, another imgui window) already
-- holds a cursor when we open, we never push our own; when that owner later pops,
-- the window is left open with no cursor while the using_input hook still returns
-- true -> visible-but-unclickable freeze. (Matches custom_hud's working idiom.)
function ManagementWindow:_ensure_cursor()
    local input_manager = Managers.input
    if not input_manager then
        return
    end

    if not self._cursor_pushed then
        input_manager:push_cursor(self.__class_name)
        self._cursor_pushed = true
    elseif not input_manager:cursor_active() then
        -- We pushed, but a game-state transition reset the cursor stack while
        -- is_open stayed true. Re-push so the window is clickable again.
        input_manager:push_cursor(self.__class_name)
    end
end

function ManagementWindow:open()
    self:_load_buffs_data()
    self:_create_ui_components()

    self.is_open = true
    self:_ensure_cursor()
    Imgui.open_imgui()
end

function ManagementWindow:close()
    local input_manager = Managers.input
    local name = self.__class_name

    -- Pop exactly the cursor we pushed. Guard input_manager: close() can run
    -- mid game-state transition (on_game_state_changed) when it may be gone.
    if input_manager and self._cursor_pushed then
        input_manager:pop_cursor(name)
    end
    self._cursor_pushed = false
    -- Clear the ESC edge latch so a held-ESC close doesn't block the next open's
    -- first ESC press (update() returns early while closed, never resetting it).
    self._esc_was_down = false

    self:_save_buffs_data()
    self:_destroy_ui_components()

    self.is_open = false
    Imgui.close_imgui()
end

function ManagementWindow:invalidate_catalog_cache()
    self._catalog_cache = nil
    self._catalog_cache_ready = false
    self._buffs_data = nil
    self._buffs_data_cache_ready = false
end

function ManagementWindow:reindex_catalog()
    self:invalidate_catalog_cache()

    local buffs_data = self:_reindex_catalog_data()
    local raw_buffs_data = mod:get(BUFFS_DATA_SETTING_ID)

    buffs_data = _clone_buffs_data(buffs_data)
    _overlay_saved_assignments(buffs_data, raw_buffs_data)

    self._buffs_data = buffs_data
    self._buffs_data_cache_ready = true

    if self.is_open then
        self:_destroy_ui_components()
        self:_create_ui_components()
    end
end

function ManagementWindow:_update_components()
    self._settings_component:update()

    Imgui.separator()

    self._buff_bars_component:update()

    Imgui.separator()

    self._search_component:update()
end

-- Re-bake the buff bars after a user-initiated close ([X]/ESC) so position,
-- direction, order-mode and buff-assignment edits apply immediately -- the same
-- recreate the keybind-toggle close does. pcall-guarded; only called from the
-- in-mission update() path (recreate_hud calls local_player(1), which C-crashes
-- with no human players, so never wire this into the state-transition close).
function ManagementWindow:_recreate_hud_after_close()
    local recreate = mod.recreate_buff_hud
    if type(recreate) ~= 'function' then
        return
    end

    local ok, err = pcall(recreate)
    if not ok then
        mod:error('[ManagementWindow] hud recreate failed: %s', tostring(err))
    end
end

function ManagementWindow:update()
    if not self.is_open then
        return
    end

    -- Self-heal: a game-state transition can drop our pushed cursor while
    -- is_open stays true, leaving the window visible but unclickable -- and the
    -- game frozen because the using_input hook still returns true. Re-assert it.
    -- Also covers the case where open() ran while another owner held the cursor.
    self:_ensure_cursor()

    -- ESC-to-close escape hatch: the toggle keybind can be swallowed when an imgui
    -- text field (search box) holds keyboard focus. ESC gives a second way out.
    -- Edge-triggered so holding ESC fires once, not every frame.
    local esc_down = _esc_pressed()
    if esc_down and not self._esc_was_down then
        self._esc_was_down = true
        self:close()
        self:_recreate_hud_after_close()
        return
    end
    self._esc_was_down = esc_down

    -- Drive size + position from the mod-menu sliders every frame, and disable
    -- in-game resize/move (unstable). Window geometry is slider-only.
    Imgui.set_next_window_size(_geom(WINDOW_WIDTH_SETTING_ID, 800), _geom(WINDOW_HEIGHT_SETTING_ID, 500))
    Imgui.set_next_window_pos(_geom(WINDOW_X_SETTING_ID, 200), _geom(WINDOW_Y_SETTING_ID, 150))

    local _, closed = Imgui.begin_window(mod:localize('mod_name'), 'no_resize', 'no_move')
    if closed then
        self:close()
        -- Balance the imgui stack BEFORE recreating the HUD, so a recreate error
        -- can't leave begin_window unmatched (which freezes all input).
        Imgui.end_window()
        self:_recreate_hud_after_close()
        return
    else
        -- pcall the body so a component error can't skip end_window and leave
        -- the imgui stack unbalanced, which freezes ALL input until reload.
        local ok, err = pcall(self._update_components, self)
        if not ok then
            mod:error('[ManagementWindow] update failed: %s', tostring(err))
        end
    end
    Imgui.end_window()
end

return ManagementWindow
