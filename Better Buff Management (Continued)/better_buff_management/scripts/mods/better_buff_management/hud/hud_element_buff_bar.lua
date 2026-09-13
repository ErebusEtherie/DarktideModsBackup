require('scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_polling')

local mod = get_mod('better_buff_management')
mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/utilities/table')
local BuffBarDefinitions = mod:io_dofile(
'better_buff_management/scripts/mods/better_buff_management/hud/hud_element_buff_bar_definitions')

-- Cache vanilla definitions for the temporary swap trick
local VanillaDefinitions = require(
    'scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_definitions'
)

local PlayerBuffsSettings = require(
    'scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_settings'
)

local BuffSettings = require('scripts/settings/buff/buff_settings')
local buff_categories = BuffSettings.buff_categories
local buff_category_order = BuffSettings.buff_category_order

local GROUP_BUFFS_IN_CATEGORIES_SETTING_ID = 'group_buffs_in_categories'

-- Half a buff-slot gap inserted between non-empty categories, identical to the
-- vanilla default bar (HudElementPlayerBuffs._update_buff_alignments).
local GAP_OFFSET_SIZE = 0.5

-- Half the buff node's width. Buff icons are left-aligned in their node (offset
-- x=0 puts the node's LEFT edge at the anchor, so the icon center sits half a node
-- to the right). For 'center' direction we subtract this so the row's visual
-- midpoint lands exactly on the bar's anchor, not half an icon off.
local _buff_size = BuffBarDefinitions.scenegraph_definition
    and BuffBarDefinitions.scenegraph_definition.buff
    and BuffBarDefinitions.scenegraph_definition.buff.size
local BUFF_NODE_HALF_WIDTH = ((_buff_size and _buff_size[1]) or 38) * 0.5

-- Scratch maps reused across frames to avoid per-frame allocation.
local _number_of_buffs_per_category = {}
local _category_numbers = {}

local function _clear_map(tbl)
    if table.clear then
        table.clear(tbl)
        return
    end

    for k in pairs(tbl) do
        tbl[k] = nil
    end
end

-- Localized hot-path globals
local type = type
local math_lerp = math.lerp

-- Per-bar growth direction. Map a scalar slot position (in buff-slot units) to an
-- (x, y) offset. Origin is the bar's scenegraph anchor (top-left); positive x =
-- right, positive y = down.
local function _axis_offset(direction, spacing, p)
    if direction == 'right_left' then
        return -spacing * p, 0
    elseif direction == 'top_bottom' then
        return 0, spacing * p
    elseif direction == 'bottom_top' then
        return 0, -spacing * p
    end
    -- left_right (default)
    return spacing * p, 0
end

-- Fade the stack-count text + its background rect along with the icon.
--
-- Only the icon and frame passes have a change_function reading content.opacity;
-- the text and text_background passes don't, so they'd stay fully opaque on a
-- dimmed bar. Their alphas are otherwise STATIC -- _set_widget_state_colors skips
-- the text pass (it has a text_color) and has no source color for
-- text_background, and _return_widget doesn't reset either -- so capture the base
-- alpha once per widget and always rescale from that base (never compound).
-- widget.style is a per-widget copy, so this can't leak across bars.
local function _apply_text_alpha(widget, opacity)
    local style = widget.style
    if not style then
        return
    end

    local text_style = style.text
    local bg_style = style.text_background

    if widget._bbm_base_text_alpha == nil then
        local base_text_color = text_style and text_style.text_color
        widget._bbm_base_text_alpha = (base_text_color and base_text_color[1]) or 255

        local base_bg_color = bg_style and bg_style.color
        widget._bbm_base_text_bg_alpha = (base_bg_color and base_bg_color[1]) or 150
    end

    local text_color = text_style and text_style.text_color
    if text_color then
        text_color[1] = widget._bbm_base_text_alpha * opacity
    end

    local bg_color = bg_style and bg_style.color
    if bg_color then
        bg_color[1] = widget._bbm_base_text_bg_alpha * opacity
    end
end

-- Ease a widget toward its target (tx, ty), matching vanilla's lerp/fade-in feel
-- but on both axes so vertical bars animate too. max_opacity is the bar's opacity
-- cap (0-1): the fade-in eases toward it instead of a hardcoded 1, and content.
-- opacity drives the icon+frame material opacity via their change_functions.
local function _apply_offset(widget, tx, ty, force_update, dt, direction, spacing, max_opacity)
    local content = widget.content
    local offset = widget.offset
    local old_x = offset[1]
    local old_y = offset[2]
    local old_opacity = content.opacity

    if force_update then
        offset[1] = tx
        offset[2] = ty
    elseif widget.initialize_offset then
        widget.initialize_offset = nil
        -- Slide in from one slot further along the growth axis.
        local dx, dy = _axis_offset(direction, spacing, 1)
        offset[1] = tx + dx
        offset[2] = ty + dy
        content.opacity = 0
    else
        offset[1] = math_lerp(old_x, tx, dt * 6)
        offset[2] = math_lerp(old_y, ty, dt * 6)
        content.opacity = math_lerp(old_opacity, max_opacity, dt * 4)
    end

    local opacity_changed = old_opacity ~= content.opacity
    if opacity_changed then
        _apply_text_alpha(widget, content.opacity)
    end

    -- Dirty only on real change (retained-mode: don't re-submit a settled widget).
    if force_update or old_x ~= offset[1] or old_y ~= offset[2] or opacity_changed then
        widget.dirty = true
    end
end

-- Comparator for 'preserved' order mode. Sorts by a precomputed slot stamped on
-- each buff_data (_bbm_order_slot); see _update_buff_alignments. Stamping happens
-- outside the sort so the name resolution runs once per buff, not O(n log n).
local function _preserved_compare(a, b)
    local ia = a._bbm_order_slot or 1e9
    local ib = b._bbm_order_slot or 1e9
    if ia == ib then
        return (a.start_index or 0) < (b.start_index or 0)
    end
    return ia < ib
end

-- Per-instance scenegraph clone so each bar can sit at its own screen position.
-- Only the background anchor differs between bars; screen/buff nodes are shared
-- read-only. A fresh position table avoids bars aliasing one coordinate.
local function _clone_scenegraph_with_position(base, pos_x, pos_y)
    local bg = base.background
    return {
        screen = base.screen,
        background = {
            horizontal_alignment = bg.horizontal_alignment,
            parent = bg.parent,
            vertical_alignment = bg.vertical_alignment,
            size = bg.size,
            position = { pos_x, pos_y, bg.position[3] or 1 },
        },
        buff = base.buff,
    }
end

local function _resolve_recent_buff_name(buff_instance)
    if buff_instance == nil then
        return nil
    end
    -- Cache hit: name doesn't change for a buff_instance after first resolution.
    -- Saves 4-5 type() + 1-2 C-call name resolutions per buff per filter check.
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
        buff_instance._bbm_template_name = false  -- negative cache
        return nil
    end

    buff_instance._bbm_template_name = template_name
    return template_name
end

-- Weapon-trait/talent buffs that split into a parent + an internally-controlled
-- child render as the CHILD: the parent proc_buff has no duration/active_duration/
-- cooldown, so ProcBuff:has_hud() is false and it never draws, while the child
-- inherits the weapon's icon through its "parent_buff_template" override data.
-- Only the parent name reaches the config window (window.lua's get_icon resolves
-- an icon by matching item.trait, which equals the parent buff name), so every
-- assignment is keyed on the parent. Resolve the child's parent name so it can be
-- matched too. Cached per instance; the value never changes after creation.
local function _resolve_parent_buff_name(buff_instance)
    if buff_instance == nil then
        return nil
    end

    local cached = buff_instance._bbm_parent_name
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local parent_name = nil
    if type(buff_instance.parent_buff_template) == 'function' then
        parent_name = buff_instance:parent_buff_template()
    end

    if type(parent_name) ~= 'string' or parent_name == '' then
        buff_instance._bbm_parent_name = false  -- negative cache
        return nil
    end

    buff_instance._bbm_parent_name = parent_name
    return parent_name
end

-- Keystone parent/child pairs are the INVERSE of the weapon-trait case above:
-- the PARENT renders (always_show_in_hud + hud_icon, e.g. ogryn_carapace_armor_
-- parent for Feel No Pain) while the child has no hud_icon and never reaches the
-- HUD. The catalog lists the child too (get_icon resolves its icon through the
-- parent), so an assignment can be keyed on the child name. Resolve the rendered
-- parent's child_buff_template so that assignment matches. Cached per instance.
local function _resolve_child_buff_name(buff_instance)
    if buff_instance == nil then
        return nil
    end

    local cached = buff_instance._bbm_child_name
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local buff_template = nil
    if type(buff_instance.template) == 'function' then
        buff_template = buff_instance:template()
    end

    local child_name = buff_template and buff_template.child_buff_template or nil
    if type(child_name) ~= 'string' or child_name == '' then
        buff_instance._bbm_child_name = false  -- negative cache
        return nil
    end

    buff_instance._bbm_child_name = child_name
    return child_name
end

local function _filter_matches_buff(filter, buff_instance)
    if filter == nil or buff_instance == nil then
        return false
    end
    -- Cached single-lookup. _resolve_recent_buff_name already tries all 3 name
    -- shapes (template().name → _template_name → :template_name()) and caches
    -- the winner on buff_instance, so one filter lookup covers all cases.
    local template_name = _resolve_recent_buff_name(buff_instance)
    if template_name and filter[template_name] then
        return true
    end

    local parent_name = _resolve_parent_buff_name(buff_instance)
    if parent_name and filter[parent_name] then
        return true
    end

    local child_name = _resolve_child_buff_name(buff_instance)
    if child_name and filter[child_name] then
        return true
    end

    return false
end

local function _record_buff_instance(buff_instance)
    if buff_instance == nil or buff_instance._bbm_recent_recorded then
        return
    end

    local template_name = _resolve_recent_buff_name(buff_instance)
    if template_name then
        mod:record_recent_buff(template_name)
        buff_instance._bbm_recent_recorded = true
    end
end

local function _clear_array(tbl)
    if table.clear then
        table.clear(tbl)
        return
    end

    for i = #tbl, 1, -1 do
        tbl[i] = nil
    end
end

-- -------------------------------
-- --------- Constructor ---------
-- -------------------------------
local HudElementBuffBar = class('HudElementBuffBar', 'HudElementPlayerBuffs')
function HudElementBuffBar:init(parent, draw_layer, start_scale, filter, bar_config)
    -- Per-bar position/direction/order, baked at creation (recreate_hud on edit).
    local pos_x, pos_y = 0, 0
    local direction = 'left_right'
    local order_mode = 'activation'
    local order_index = nil
    local opacity = 1
    -- nil = show on all classes; otherwise a map { archetype_name = true }.
    local classes = nil
    if type(bar_config) == 'table' then
        pos_x = tonumber(bar_config.pos_x) or 0
        pos_y = tonumber(bar_config.pos_y) or 0
        direction = bar_config.direction or direction
        order_mode = bar_config.order_mode or order_mode
        order_index = bar_config.order_index
        opacity = tonumber(bar_config.opacity) or 1
        if opacity < 0 then opacity = 0 elseif opacity > 1 then opacity = 1 end
        if type(bar_config.classes) == 'table' then
            classes = bar_config.classes
        end
    end

    -- Instance state MUST exist before super.init: the vanilla init calls
    -- self:_update_buff_alignments(true, 0), which is our override and reads
    -- these fields (nil _layout_scratch -> table.clear(nil) crash otherwise).
    self._filter = filter
    self._filtered_buffs_cache = {}
    self._layout_scratch = {}
    self._direction = direction
    self._order_mode = order_mode
    self._order_index = order_index
    self._opacity = opacity
    -- Class restriction + lazily-resolved verdict for the local player (archetype
    -- is fixed for a mission, so cache once resolved). nil classes => always shown.
    self._classes = classes
    self._class_allowed = nil
    -- Cached once; setting changes recreate the HUD (mod.on_setting_changed).
    self._use_categories = mod:get(GROUP_BUFFS_IN_CATEGORIES_SETTING_ID) and true or false

    -- Per-instance definitions carrying this bar's own positioned scenegraph.
    local defs = {
        animations = BuffBarDefinitions.animations,
        buff_widget_definition = BuffBarDefinitions.buff_widget_definition,
        widget_definitions = BuffBarDefinitions.widget_definitions,
        scenegraph_definition = _clone_scenegraph_with_position(
            BuffBarDefinitions.scenegraph_definition, pos_x, pos_y),
    }

    -- The parent class re-requires vanilla definitions internally.
    -- Temporarily swap the vanilla scenegraph so the engine builds
    -- the live scenegraph from our values.
    local orig_scenegraph = VanillaDefinitions.scenegraph_definition
    local orig_widget_defs = VanillaDefinitions.widget_definitions
    local orig_buff_def = VanillaDefinitions.buff_widget_definition

    VanillaDefinitions.scenegraph_definition = defs.scenegraph_definition
    VanillaDefinitions.widget_definitions = defs.widget_definitions
    VanillaDefinitions.buff_widget_definition = defs.buff_widget_definition

    HudElementBuffBar.super.init(self, parent, draw_layer, start_scale, defs)

    -- Restore vanilla definitions immediately
    VanillaDefinitions.scenegraph_definition = orig_scenegraph
    VanillaDefinitions.widget_definitions = orig_widget_defs
    VanillaDefinitions.buff_widget_definition = orig_buff_def

    self._definitions = defs
end

-- -------------------------------
-- ------- Event Functions -------
-- -------------------------------

function HudElementBuffBar:event_player_buff_added(player, buff_instance)
    _record_buff_instance(buff_instance)

    if _filter_matches_buff(self._filter, buff_instance) then
        HudElementBuffBar.super.event_player_buff_added(self, player, buff_instance)
    end
end

function HudElementBuffBar:event_player_buff_stack_added(player, buff_instance)
    _record_buff_instance(buff_instance)

    if _filter_matches_buff(self._filter, buff_instance) then
        HudElementBuffBar.super.event_player_buff_stack_added(self, player, buff_instance)
    end
end

-- -------------------------------
-- ------ Private Functions ------
-- -------------------------------

function HudElementBuffBar:_sync_current_active_buffs(buffs)
    if not buffs then
        return
    end

    local filter = self._filter
    local filtered_buffs = self._filtered_buffs_cache
    _clear_array(filtered_buffs)

    local count = 0
    for i = 1, #buffs do
        local buff = buffs[i]
        _record_buff_instance(buff)

        if filter and _filter_matches_buff(filter, buff) then
            count = count + 1
            filtered_buffs[count] = buff
        end
    end

    if not filter or count == 0 then
        return
    end

    HudElementBuffBar.super._sync_current_active_buffs(self, filtered_buffs)
end

-- Single-row layout. Vanilla _update_buff_alignments lifts negative buffs
-- (debuffs) by -42 -- that is the vanilla two-row positive/negative split.
-- In a buff bar every icon must sit on ONE row inside the box, so lay them
-- all out in a single sequence at y = 0 regardless of sign. is_negative is
-- left intact, so debuff frame colouring still works.
--
-- When self._use_categories is set, buffs are grouped by buff_category in
-- buff_category_order with a half-buff gap between non-empty categories --
-- the same grouping the vanilla default bar applies, flattened onto one row
-- so it also covers negative buffs (which share this single row).
function HudElementBuffBar:_update_buff_alignments(force_update, dt)
    local active_buffs_data = self._active_buffs_data
    if not active_buffs_data then
        return
    end

    local spacing = PlayerBuffsSettings.horizontal_spacing
    local direction = self._direction or 'left_right'
    local opacity = self._opacity or 1
    local num_active_buffs = #active_buffs_data
    local use_categories = self._use_categories
    local preserved = self._order_mode == 'preserved' and self._order_index ~= nil

    -- Gather the active (widgeted) buffs once. Both layout paths iterate this.
    local ordered = self._layout_scratch
    _clear_array(ordered)

    local count = 0
    for i = 1, num_active_buffs do
        local buff_data = active_buffs_data[i]
        if buff_data and buff_data.widget then
            count = count + 1
            ordered[count] = buff_data
        end
    end

    if preserved then
        -- Stable relative order by config index; active_buffs_data is otherwise in
        -- vanilla activation order (see _compare_buffs), which makes buffs shuffle
        -- spots as they re-trigger. Resolve each buff's name the SAME way the
        -- filter does (template().name -> _template_name -> template_name());
        -- vanilla's buff_data.buff_name is only template().name and can be a
        -- different shape than the assignment key, missing the order_index --
        -- and for parent/child buffs the key can be the parent's name (weapon
        -- traits render the child) or the child's name (keystones render the
        -- parent), so fall back to both like the filter does.
        -- This sort also gives stable order WITHIN each category below: the
        -- per-category cursor advances in whatever order we walk `ordered`.
        local order_index = self._order_index
        for slot = 1, count do
            local buff_data = ordered[slot]
            local buff_instance = buff_data.buff_instance
            local name = _resolve_recent_buff_name(buff_instance)
            local slot = name and order_index[name] or nil

            if slot == nil then
                local parent_name = _resolve_parent_buff_name(buff_instance)
                slot = parent_name and order_index[parent_name] or nil
            end

            if slot == nil then
                local child_name = _resolve_child_buff_name(buff_instance)
                slot = child_name and order_index[child_name] or nil
            end

            buff_data._bbm_order_slot = slot or 1e9
        end
        table.sort(ordered, _preserved_compare)
    end

    if use_categories then
        -- Group by buff_category in buff_category_order with a half-buff gap
        -- between non-empty categories (flattened onto one row, like the vanilla
        -- default bar). Compatible with 'preserved': grouping decides the block a
        -- buff lands in, order_mode decides its slot within that block.
        _clear_map(_number_of_buffs_per_category)

        for i = 1, count do
            local buff_data = ordered[i]
            local buff_category = buff_data.buff_category or buff_categories.generic
            _number_of_buffs_per_category[buff_category] = (_number_of_buffs_per_category[buff_category] or 0) + 1
        end

        _clear_map(_category_numbers)

        local current_number = 0
        local nonempty_categories = 0
        for _, buff_category in ipairs(buff_category_order) do
            local number_in_category = _number_of_buffs_per_category[buff_category] or 0
            _category_numbers[buff_category] = current_number
            current_number = current_number + number_in_category + (number_in_category > 0 and GAP_OFFSET_SIZE or 0)
            if number_in_category > 0 then
                nonempty_categories = nonempty_categories + 1
            end
        end

        -- 'center': shift the whole grouped run (buffs + inter-category gaps) by
        -- half its span so it stays centered on the anchor.
        local shift = 0
        local center_px = 0
        if direction == 'center' then
            local span = count + (nonempty_categories > 0 and (nonempty_categories - 1) * GAP_OFFSET_SIZE or 0)
            shift = (span - 1) * 0.5
            center_px = BUFF_NODE_HALF_WIDTH
        end

        for i = 1, count do
            local buff_data = ordered[i]
            local buff_category = buff_data.buff_category or buff_categories.generic
            local aligned = _category_numbers[buff_category] or 0
            local tx, ty = _axis_offset(direction, spacing, aligned - shift)
            _apply_offset(buff_data.widget, tx - center_px, ty, force_update, dt, direction, spacing, opacity)
            _category_numbers[buff_category] = aligned + 1
        end

        return
    end

    -- Single-row/column layout: pack sequentially along the growth axis, gaps
    -- collapsed. Order is `ordered` as-gathered (activation) or preserved-sorted.
    -- 'center' shifts the whole run by half its length so it stays centered on
    -- the anchor and grows both ways.
    local centered = direction == 'center'
    local shift = centered and (count - 1) * 0.5 or 0
    local center_px = centered and BUFF_NODE_HALF_WIDTH or 0
    for slot = 1, count do
        local widget = ordered[slot].widget
        local tx, ty = _axis_offset(direction, spacing, (slot - 1) - shift)
        _apply_offset(widget, tx - center_px, ty, force_update, dt, direction, spacing, opacity)
    end
end

-- -------------------------------
-- ------- Public Functions ------
-- -------------------------------

-- Resolve the local player's archetype (class) name, tolerating either the
-- HumanPlayer:archetype_name() helper or a raw profile.archetype.name. Returns nil
-- if it can't be read yet (e.g. profile not populated during early frames).
function HudElementBuffBar:_resolve_archetype()
    local player = self._player
    if not player then
        return nil
    end

    if type(player.archetype_name) == 'function' then
        local ok, name = pcall(player.archetype_name, player)
        if ok and type(name) == 'string' and name ~= '' then
            return name
        end
    end

    if type(player.profile) == 'function' then
        local ok, profile = pcall(player.profile, player)
        if ok and type(profile) == 'table' and type(profile.archetype) == 'table' then
            local name = profile.archetype.name
            if type(name) == 'string' and name ~= '' then
                return name
            end
        end
    end

    return nil
end

-- Whether this bar shows for the local player's class. Fail-open: if the class
-- restriction is set but the archetype can't be resolved yet, show the bar (don't
-- blank the user's buffs over a transient read miss) and don't cache the verdict.
function HudElementBuffBar:_is_class_allowed()
    local classes = self._classes
    if classes == nil then
        return true
    end

    if self._class_allowed ~= nil then
        return self._class_allowed
    end

    local archetype = self:_resolve_archetype()
    if archetype == nil then
        return true
    end

    local allowed = classes[archetype] and true or false
    self._class_allowed = allowed
    return allowed
end

function HudElementBuffBar:draw(dt, t, ui_renderer, render_settings, input_service)
    if self._is_hidden then
        return
    end

    if mod:is_in_hub() then
        return
    end

    if not self:_is_class_allowed() then
        return
    end

    HudElementBuffBar.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudElementBuffBar
