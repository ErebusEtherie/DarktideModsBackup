local mod = get_mod("better_buff_management")
mod:io_dofile("better_buff_management/scripts/mods/better_buff_management/utilities/string")
mod:io_dofile("better_buff_management/scripts/mods/better_buff_management/utilities/table")
mod:io_dofile("better_buff_management/scripts/mods/better_buff_management/utilities/imgui")
mod:io_dofile("better_buff_management/scripts/mods/better_buff_management/ui/components/base_buff_component")
local UiSettings = mod:io_dofile("better_buff_management/scripts/mods/better_buff_management/ui/settings")

local BUFF_TEMPLATES = require("scripts/settings/buff/buff_templates")

local MOD_NAME = mod:localize("mod_name")
local CLASS_NAME = "SearchComponent"

local ERROR_PREFIX = ("[%s][%s]"):format(MOD_NAME, CLASS_NAME)
local ERRORS = {
}

local BARS_SETTING_ID = "bars"
local DESELECT_VISIBLE_ICONS_LOC_ID = "unselect_all_icons"
local SELECT_VISIBLE_ICONS_LOC_ID = "select_all_icons"
local SEARCH_LOC_ID = "search"
local CLEAR_SEARCH_LOC_ID = "clear_search"
local ADD_SELECTED_BUFFS_BAR_LOC_ID = "add_selected_buffs_bar"
local SHOW_ONLY_UNASSIGNED_LOC_ID = "show_only_unassigned"
local RECENTLY_SEEN_BUFFS_LOC_ID = "recently_seen_buffs"
local CLEAR_RECENT_LOC_ID = "clear_recent"
local RECENT_BUFFS_HELP_LOC_ID = "recent_buffs_help"
local RECENT_BUFFS_DISPLAY_LIMIT_SETTING_ID = "recent_buffs_display_limit"

local PARENT_BY_CHILD = {}

local function _map_child(child_name, template_name)
    if type(child_name) == "string" and child_name ~= "" and PARENT_BY_CHILD[child_name] == nil then
        PARENT_BY_CHILD[child_name] = template_name
    end
end

for template_name, template in pairs(BUFF_TEMPLATES) do
    if type(template_name) == "string" and type(template) == "table" then
        _map_child(template.child_buff_template, template_name)

        -- Weapon-trait proc buffs spawn their icon-bearing child through
        -- buff_data.internal_buff_name instead of child_buff_template (see
        -- base_weapon_trait_buff_templates guaranteed_melee_crit_on_activated_kill).
        -- Only the parent is assignable (the child has no icon of its own and never
        -- reaches the catalog), so the recorded child name must alias back to it.
        local buff_data = template.buff_data
        if type(buff_data) == "table" then
            _map_child(buff_data.internal_buff_name, template_name)
        end
    end
end

-- -------------------------------
-- ------- Local Functions -------
-- -------------------------------

local function _normalize_buff_name(buff_name)
    if type(buff_name) ~= "string" then
        return nil
    end

    local normalized_name = buff_name:gsub("_parent$", ""):gsub("_child$", ""):gsub("_proc$", "")
    if normalized_name == "" then
        return nil
    end

    return normalized_name
end

local function _set_alias(alias_index, alias_name, search_entry)
    if type(alias_name) ~= "string" or alias_name == "" then
        return
    end

    if alias_index[alias_name] == nil then
        alias_index[alias_name] = search_entry
    end
end

local function _init_search_data(buffs_data)
    local search_data = {}
    for key, value in pairs(buffs_data) do
        if type(key) == "string" and type(value) == "table" and type(value.name) == "string" then
            search_data[key] = { buff = value, is_selected = false }
        end
    end
    return search_data
end

local function _build_recent_alias_index(search_data)
    local alias_index = {}

    for key, search_entry in pairs(search_data) do
        local buff = search_entry.buff
        if buff and buff.icon and buff.icon ~= "" then
            local buff_name = buff.name or key
            local normalized_name = _normalize_buff_name(buff_name)
            local template = BUFF_TEMPLATES[buff_name] or BUFF_TEMPLATES[normalized_name]

            _set_alias(alias_index, key, search_entry)
            _set_alias(alias_index, buff_name, search_entry)
            _set_alias(alias_index, normalized_name, search_entry)

            if normalized_name then
                _set_alias(alias_index, normalized_name .. "_parent", search_entry)
                _set_alias(alias_index, normalized_name .. "_child", search_entry)
                _set_alias(alias_index, normalized_name .. "_proc", search_entry)
            end

            if type(template) == "table" then
                _set_alias(alias_index, template.name, search_entry)
                _set_alias(alias_index, template.child_buff_template, search_entry)

                -- The child this parent spawns internally is what actually renders,
                -- so that is the name the observer records into the recent list.
                local buff_data = template.buff_data
                if type(buff_data) == "table" then
                    _set_alias(alias_index, buff_data.internal_buff_name, search_entry)
                end
            end

            _set_alias(alias_index, PARENT_BY_CHILD[buff_name], search_entry)
            _set_alias(alias_index, PARENT_BY_CHILD[normalized_name], search_entry)
        end
    end

    return alias_index
end

local function _resolve_recent_entry(alias_index, buff_name)
    if type(buff_name) ~= "string" or buff_name == "" then
        return nil
    end

    local normalized_name = _normalize_buff_name(buff_name)
    return alias_index[buff_name] or alias_index[normalized_name] or alias_index[(normalized_name or "") .. "_parent"] or
        alias_index[(normalized_name or "") .. "_child"] or alias_index[(normalized_name or "") .. "_proc"] or nil
end

-- -------------------------------
-- --------- Constructor ---------
-- -------------------------------
local SearchComponent = class(CLASS_NAME, "BaseBuffComponent")
function SearchComponent:init(buffs_data)
    SearchComponent.super.init(self, buffs_data)

    self._search_data = _init_search_data(buffs_data)
    self._recent_alias_index = _build_recent_alias_index(self._search_data)
    self._sorted_search_data = table.sorted_by_value(self._search_data, function(dataA, dataB)
        return dataA.buff.name < dataB.buff.name
    end)
    self._search_text = ""
    self._search_text_lower = ""
    self._selected_bar_index = nil
    self._show_only_unassigned = false
    self._buffs_data_revision = -1
    self._filtered_search_data = {}
    self._search_results_dirty = true
    self._recent_search_data_cache = {}
    self._recent_cache_revision = -1
    self._recent_cache_display_limit = -1
    self._recent_cache_only_unassigned = nil
    self._recent_cache_buffs_data_revision = -1
end

-- -------------------------------
-- ------ Private Functions ------
-- -------------------------------

function SearchComponent:_set_search_text(search_text)
    search_text = string.sanitize(search_text or "", "[^%w_]+")
    if search_text ~= self._search_text then
        self._search_text = search_text
        self._search_text_lower = search_text:lower()
        self._search_results_dirty = true
    end
end

function SearchComponent:_matches_search(buff_name)
    if type(buff_name) ~= "string" then
        return false
    end

    local lower_search = self._search_text_lower
    if lower_search == "" then
        return true
    end

    return buff_name:lower():find(lower_search, 1, true) ~= nil
end

local function _buff_is_assigned(search_data)
    local bar_name = search_data and search_data.buff and search_data.buff.bar_name
    return not string.is_nil_or_whitespace(bar_name)
end

function SearchComponent:_rebuild_filtered_search_data()
    local filtered = self._filtered_search_data
    if table.clear then
        table.clear(filtered)
    else
        for i = #filtered, 1, -1 do
            filtered[i] = nil
        end
    end

    local only_unassigned = self._show_only_unassigned
    local count = 0
    for i = 1, #self._sorted_search_data do
        local search_data = self._sorted_search_data[i]
        if self:_matches_search(search_data.buff.name)
            and not (only_unassigned and _buff_is_assigned(search_data)) then
            count = count + 1
            filtered[count] = search_data
        end
    end

    self._search_results_dirty = false
end

function SearchComponent:_toggle_all_selected(flag)
    if self._search_results_dirty then
        self:_rebuild_filtered_search_data()
    end

    for i = 1, #self._filtered_search_data do
        self._filtered_search_data[i].is_selected = flag
    end
end

function SearchComponent:_get_recent_search_data()
    local display_limit = tonumber(mod:get(RECENT_BUFFS_DISPLAY_LIMIT_SETTING_ID)) or 30
    display_limit = math.max(5, math.min(50, math.floor(display_limit)))

    -- "Show only buffs not on a bar" filters the recent list too. Assignment
    -- state changes bump the buffs_data revision, so fold both the toggle and
    -- that revision into the cache key to keep the cached list correct.
    local only_unassigned = self._show_only_unassigned
    local revision = mod:get_recent_buffs_revision()
    local buffs_data_revision = mod:get_buffs_data_revision()
    if revision == self._recent_cache_revision
        and display_limit == self._recent_cache_display_limit
        and only_unassigned == self._recent_cache_only_unassigned
        and buffs_data_revision == self._recent_cache_buffs_data_revision then
        return self._recent_search_data_cache
    end

    local recent_search_data = self._recent_search_data_cache
    local recent_buffs = mod:get_recent_buffs() or {}
    local added = {}

    if table.clear then
        table.clear(recent_search_data)
    else
        for i = #recent_search_data, 1, -1 do
            recent_search_data[i] = nil
        end
    end

    local count = 0
    for i = 1, #recent_buffs do
        local buff_name = recent_buffs[i]
        local buff_data = _resolve_recent_entry(self._recent_alias_index, buff_name)
        if buff_data and buff_data.buff and buff_data.buff.icon and buff_data.buff.icon ~= ""
            and not added[buff_data.buff.name]
            and not (only_unassigned and _buff_is_assigned(buff_data)) then
            count = count + 1
            recent_search_data[count] = buff_data
            added[buff_data.buff.name] = true

            if count >= display_limit then
                break
            end
        end
    end

    self._recent_cache_revision = revision
    self._recent_cache_display_limit = display_limit
    self._recent_cache_only_unassigned = only_unassigned
    self._recent_cache_buffs_data_revision = buffs_data_revision

    return recent_search_data
end

function SearchComponent:_update_search_inputs()
    local search_text = Imgui.input_text(mod:localize(SEARCH_LOC_ID), self._search_text)
    self:_set_search_text(search_text)

    Imgui.same_line()
    Imgui.push_id(self.__class_name .. "_" .. CLEAR_SEARCH_LOC_ID:upper())
    if Imgui.button(mod:localize(CLEAR_SEARCH_LOC_ID)) then
        self:_set_search_text("")
    end
    Imgui.pop_id()

    if Imgui.button(mod:localize(SELECT_VISIBLE_ICONS_LOC_ID)) then
        self:_toggle_all_selected(true)
    end

    Imgui.same_line()

    if Imgui.button(mod:localize(DESELECT_VISIBLE_ICONS_LOC_ID)) then
        self:_toggle_all_selected(false)
    end

    local new_flag = Imgui.checkbox(mod:localize(SHOW_ONLY_UNASSIGNED_LOC_ID), self._show_only_unassigned)
    if new_flag ~= self._show_only_unassigned then
        self._show_only_unassigned = new_flag
        self._search_results_dirty = true
    end
end

function SearchComponent:_get_bars()
    local bars = mod:get(BARS_SETTING_ID)

    if bars == nil then
        bars = {}
    end

    return bars
end

function SearchComponent:_draw_buff(search_data)
    if type(search_data) ~= "table" or type(search_data.buff) ~= "table" then
        return
    end

    local is_clicked = false
    local icon = search_data.buff.icon

    if not icon or icon == "" then
        return
    end

    local button_id = ("%s_%s_IMAGE_BUTTON"):format(self.__class_name, search_data.buff.name)
    Imgui.push_id(button_id)
    if search_data.is_selected then
        is_clicked = Imgui.image_button(icon, UiSettings.BUFF_IMAGE_SIZE[1],
            UiSettings.BUFF_IMAGE_SIZE[2], 266, 200, 0, 1)
    else
        is_clicked = Imgui.image_button(icon, UiSettings.BUFF_IMAGE_SIZE[1],
            UiSettings.BUFF_IMAGE_SIZE[2], 255, 255, 255, 1)
    end
    Imgui.pop_id()

    if is_clicked then
        search_data.is_selected = not search_data.is_selected
    end

    if Imgui.is_item_hovered() then
        Imgui.begin_tool_tip()
        Imgui.text(search_data.buff.name)
        Imgui.end_tool_tip()
    end
end

function SearchComponent:_update_recent_window()
    local recent_search_data = self:_get_recent_search_data()

    Imgui.text(mod:localize(RECENTLY_SEEN_BUFFS_LOC_ID))
    Imgui.same_line()
    if Imgui.button(mod:localize(CLEAR_RECENT_LOC_ID)) then
        mod:clear_recent_buffs()
        recent_search_data = self:_get_recent_search_data()
    end

    Imgui.text(mod:localize(RECENT_BUFFS_HELP_LOC_ID))

    Imgui.begin_child_window(self.__class_name .. "_RECENT_WINDOW", UiSettings.RECENT_WINDOW_SIZE[1],
        UiSettings.RECENT_WINDOW_SIZE[2], true, "always_auto_resize", "horizontal_scrollbar")

    if not table.is_nil_or_empty(recent_search_data) then
        local same_line_flag = 1
        for i = 1, #recent_search_data do
            local search_data = recent_search_data[i]
            if same_line_flag > 1 then
                Imgui.same_line()
            end

            self:_draw_buff(search_data)
            same_line_flag = same_line_flag + 1
        end
    end

    Imgui.end_child_window()
end

function SearchComponent:_update_search_window()
    if self._search_results_dirty then
        self:_rebuild_filtered_search_data()
    end

    local same_line_flag = 1
    Imgui.begin_child_window(self.__class_name .. "_SEARCH_WINDOW", UiSettings.SEARCH_WINDOW_SIZE[1],
        UiSettings.SEARCH_WINDOW_SIZE[2], true, "always_auto_resize", "horizontal_scrollbar")
    for i = 1, #self._filtered_search_data do
        if same_line_flag > 1 then
            Imgui.same_line()
        end

        self:_draw_buff(self._filtered_search_data[i])
        same_line_flag = same_line_flag + 1
    end

    Imgui.end_child_window()
end

function SearchComponent:_update_add_inputs()
    local bars = self:_get_bars()

    if Imgui.button(mod:localize(ADD_SELECTED_BUFFS_BAR_LOC_ID)) and self._selected_bar_index then
        local selected_bar = bars[self._selected_bar_index]
        local changed = false

        for _, data in pairs(self._search_data) do
            if data.is_selected then
                if data.buff.bar_name ~= selected_bar then
                    data.buff.bar_name = selected_bar
                    changed = true
                end
                data.is_selected = false
            end
        end

        if changed then
            mod:bump_buffs_data_revision()
            self._search_results_dirty = true
        end

        self._selected_bar_index = nil
    end
    Imgui.same_line()

    self._selected_bar_index = Imgui.combo(self.__class_name .. "_SELECT_BAR_INPUT", bars, self._selected_bar_index)
end

-- -------------------------------
-- ------- Public Functions ------
-- -------------------------------

function SearchComponent:update()
    -- Buff/bar assignments can change from the bars component (assign/remove),
    -- so refresh the "unassigned only" filter when the shared revision moves.
    local revision = mod:get_buffs_data_revision()
    if revision ~= self._buffs_data_revision then
        self._buffs_data_revision = revision
        if self._show_only_unassigned then
            self._search_results_dirty = true
        end
    end

    self:_update_recent_window()
    self:_update_search_inputs()
    self:_update_search_window()
    self:_update_add_inputs()
end

return SearchComponent
