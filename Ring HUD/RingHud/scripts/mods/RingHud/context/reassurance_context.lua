-- File: RingHud/scripts/mods/RingHud/context/reassurance_context.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local ReassuranceSystem     = {}

local Pickups               = require("scripts/settings/pickup/pickups")
local UISettings            = require("scripts/settings/ui/ui_settings")
local Color                 = require("scripts/utilities/ui/colors")
local Ammo                  = require("scripts/utilities/ammo")
local U                     = mod.utils or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

-- Localization keys for interactions that should trigger HUD "nudges".
-- Pre-hashed into sets for O(1) lookup performance.
local HEALING_LOC_SET       = table.set({
    "loc_health_station",
    "loc_pickup_pocketable_01",
    "loc_pickup_pocketable_medical_crate_01",
})

local AMMO_LOC_SET          = table.set({
    "loc_pickup_consumable_small_clip_01",
    "loc_pickup_consumable_large_clip_01",
    "loc_pickup_deployable_ammo_crate_01",
    "loc_pickup_pocketable_ammo_crate_01",
    "loc_action_interaction_inactive_ammo_full",
    "loc_action_interaction_inactive_no_ammo",
})

local WASTAGE_PICKUP_BY_LOC = {
    loc_pickup_consumable_small_clip_01 = "small_clip",
    loc_pickup_consumable_large_clip_01 = "large_clip",
    loc_pickup_deployable_ammo_crate_01 = "ammo_cache_deployable",
}

----------------------------------------------------------------
-- Suffix helpers
----------------------------------------------------------------
local function _strip_previous_suffix(widget)
    if not (widget and widget.content) then return nil end
    local text = widget.content.text or ""
    local suffix = widget.content._ringhud_wastage_suffix

    if suffix and suffix ~= "" then
        local n = #suffix
        if n > 0 and #text >= n and string.sub(text, #text - n + 1, #text) == suffix then
            text = string.sub(text, 1, #text - n)
        end
    end

    widget.content._ringhud_wastage_suffix = nil
    return text
end

local function _apply_suffix(widget, base_text, suffix)
    if not (widget and widget.content) then return false end

    suffix = suffix or ""
    widget.content._ringhud_wastage_suffix = (suffix ~= "" and suffix) or nil

    local next_text = (base_text or "") .. suffix
    if widget.content.text ~= next_text then
        widget.content.text = next_text
        widget.dirty = true
        return true
    end

    return false
end

----------------------------------------------------------------
-- Background Color override:
-- Changes the interaction prompt background to red when ammo will be wasted.
----------------------------------------------------------------
local function _set_input_background_color(background_widget, to_red)
    if not background_widget then return false end
    local content = background_widget.content
    if not content then return false end

    local changed = false

    local function _apply_to_style(style_id)
        local style = background_widget.style and background_widget.style[style_id]
        if not style or not style.color then return end

        content._ringhud_base_bg_colors = content._ringhud_base_bg_colors or {}
        if not content._ringhud_base_bg_colors[style_id] then
            local c = style.color
            content._ringhud_base_bg_colors[style_id] = { c[1], c[2], c[3], c[4] }
        end

        local current_c = style.color
        local base_c = content._ringhud_base_bg_colors[style_id]

        -- Switch to a distinct red, maintaining original alpha
        local target_c = to_red and { base_c[1], 200, 0, 0 } or base_c

        if current_c[1] ~= target_c[1] or current_c[2] ~= target_c[2] or current_c[3] ~= target_c[3] or current_c[4] ~= target_c[4] then
            current_c[1] = target_c[1]
            current_c[2] = target_c[2]
            current_c[3] = target_c[3]
            current_c[4] = target_c[4]
            changed = true
        end
    end

    _apply_to_style("input_background")
    _apply_to_style("input_background_slim")

    return changed
end

local function _clear_wastage_visuals(widget, bg_widget)
    if widget then
        local base = _strip_previous_suffix(widget)
        _apply_suffix(widget, base, "")
    end
    if bg_widget and _set_input_background_color(bg_widget, false) then
        bg_widget.dirty = true
    end
end

----------------------------------------------------------------
-- Interaction description icon override:
-- When minimal objective feed is enabled and the interactee is a player unit,
-- replace the vanilla hardcoded glyph "" with the player's archetype glyph.
-- Also: tint the ENTIRE description_text (glyph + name) in the player's slot colour.
----------------------------------------------------------------
local function _apply_player_archetype_glyph_to_description(self, interactee_unit, use_minimal_presentation, local_mod)
    if use_minimal_presentation then
        return
    end

    if not (local_mod._settings and local_mod._settings.minimal_objective_feed_enabled) then
        return
    end

    local pm = Managers.player
    if not pm or not pm.player_by_unit then
        return
    end

    local interactee_player = pm:player_by_unit(interactee_unit)
    if not interactee_player or interactee_player.__deleted then
        return
    end

    local widgets_by_name = self._widgets_by_name
    local desc_widget = widgets_by_name and widgets_by_name.description_text
    local desc_content = desc_widget and desc_widget.content
    if not (desc_widget and desc_content) then
        return
    end

    local glyph = (local_mod.get_archetype_glyph and local_mod.get_archetype_glyph(interactee_player, "")) or ""

    local player_slot = interactee_player:slot()
    local player_slot_color = (UISettings.player_slot_colors and UISettings.player_slot_colors[player_slot])
        or (Color and Color.ui_hud_green_light and Color.ui_hud_green_light(255, true))

    local r = (player_slot_color and player_slot_color[2]) or 255
    local g = (player_slot_color and player_slot_color[3]) or 255
    local b = (player_slot_color and player_slot_color[4]) or 255

    local color_string = "{#color(" .. r .. "," .. g .. "," .. b .. ")}"
    local name = interactee_player:name() or ""

    -- IMPORTANT:
    -- {#reset()} would clear the color, so we re-apply color for the name section.
    -- This keeps the icon large but the name at normal size, while both are slot-tinted.
    local next_text =
        color_string
        .. "{#size(30)}"
        .. glyph
        .. "{#reset()}"
        .. color_string
        .. " "
        .. name
        .. "{#reset()}"

    if desc_content.text ~= next_text then
        desc_content.text = next_text
        desc_widget.dirty = true
    end
end

function ReassuranceSystem.init()
    local local_mod = mod

    -- Swap the vanilla player glyph in HudElementInteraction description_text (player interactee only).
    mod:hook_safe("HudElementInteraction", "_setup_interaction_information",
        function(self, interactee_unit, interactee_extension, interactor_extension, use_minimal_presentation)
            _apply_player_archetype_glyph_to_description(self, interactee_unit, use_minimal_presentation, local_mod)
        end)

    mod:hook_safe("HudElementInteraction", "update", function(self)
        local presentation_data = self._active_presentation_data
        local interactor = presentation_data and presentation_data.interactor_extension
        if not interactor then
            return
        end

        local hud_description = interactor:hud_description()
        if not hud_description then
            return
        end

        local t_now = local_mod._ringhud_accumulated_time or 0

        if AMMO_LOC_SET[hud_description] then
            local_mod.reassure_ammo = true
            local_mod.reassure_ammo_last_set_time = t_now
        elseif HEALING_LOC_SET[hud_description] then
            local_mod.reassure_health = true
            local_mod.reassure_health_last_set_time = t_now
        end

        local widget = self._widgets_by_name and self._widgets_by_name.interact_text
        local bg_widget = self._widgets_by_name and self._widgets_by_name.background

        -- Ammo wastage text: only when NumericUI is NOT installed and minimal objective feed is enabled
        if local_mod._numeric_ui_installed
            or not (local_mod._settings and local_mod._settings.minimal_objective_feed_enabled)
        then
            _clear_wastage_visuals(widget, bg_widget)
            return
        end

        -- Respect: ammo_reserve_disabled => no wastage text at all
        local ammo_reserve_dropdown = local_mod._settings and local_mod._settings.ammo_reserve_dropdown
        if ammo_reserve_dropdown == "ammo_reserve_disabled" then
            _clear_wastage_visuals(widget, bg_widget)
            return
        end

        -- Only compute wastage for: small clip, large clip, deployable ammo crate
        local pickup_name = WASTAGE_PICKUP_BY_LOC[hud_description]
        if not pickup_name or not widget then
            _clear_wastage_visuals(widget, bg_widget)
            return
        end

        -- Strip any previous suffix first (so we can re-append updated value cleanly)
        local base_text = _strip_previous_suffix(widget)

        local player = Managers.player:local_player_safe(1)
        local unit = player and not player.__deleted and player.player_unit
        if not (unit and Unit.alive(unit)) then
            _clear_wastage_visuals(widget, bg_widget)
            return
        end

        local unit_data_ext = ScriptUnit.has_extension(unit, "unit_data_system")
            and ScriptUnit.extension(unit, "unit_data_system")
        if not unit_data_ext then
            _clear_wastage_visuals(widget, bg_widget)
            return
        end

        -- Secondary slot only (RingHud's ammo reserve feature is secondary slot-based)
        local component = unit_data_ext:read_component("slot_secondary")
        if not component then
            _clear_wastage_visuals(widget, bg_widget)
            return
        end

        local cur_res = U.sum_ammo_field(component.current_ammunition_reserve)
        local max_res = U.sum_ammo_field(component.max_ammunition_reserve)

        local cur_clip = 0
        local max_clip = 0
        if component.current_ammunition_clip and component.max_ammunition_clip then
            cur_clip = Ammo.current_ammo_in_clips(component) or 0
            max_clip = Ammo.max_ammo_in_clips(component) or 0
        end

        if not (max_res and max_res > 0) then
            _clear_wastage_visuals(widget, bg_widget)
            return
        end

        -- Difficulty ammo modifier (affects all these sources)
        local diff_ammo_mod = 1
        if Managers.state and Managers.state.difficulty and Managers.state.difficulty.get_ammo_modifier then
            diff_ammo_mod = Managers.state.difficulty:get_ammo_modifier() or 1
        end

        local pickup_src = Pickups.by_name and Pickups.by_name[pickup_name]
        local ammo_amount_func = pickup_src and pickup_src.ammo_amount_func

        if type(ammo_amount_func) ~= "function" then
            _clear_wastage_visuals(widget, bg_widget)
            return
        end

        -- Avoid mutating global pickup settings tables: clone + override modifier.
        local pickup_data = table.clone(pickup_src)
        pickup_data.modifier = diff_ammo_mod

        -- Precise offer_fraction for percent-mode math:
        -- tins: ammunition_percentage * diff_ammo_mod
        -- deployable ammo crate: 1.0 * diff_ammo_mod (100% reserve, modified by difficulty)
        local offer_fraction = nil
        if pickup_name == "small_clip" or pickup_name == "large_clip" then
            offer_fraction = (pickup_src.ammunition_percentage or 0) * diff_ammo_mod
        elseif pickup_name == "ammo_cache_deployable" then
            offer_fraction = 1 * diff_ammo_mod
        end

        local offer_bullets = ammo_amount_func(max_res, max_clip, pickup_data) or 0
        offer_bullets = math.floor(offer_bullets + 0.5)

        if offer_bullets <= 0 then
            _clear_wastage_visuals(widget, bg_widget)
            return
        end

        if type(local_mod.ammo_reserve_wastage_string_for_offer) ~= "function" then
            _clear_wastage_visuals(widget, bg_widget)
            return
        end

        local suffix = local_mod.ammo_reserve_wastage_string_for_offer(
            cur_res,
            max_res,
            offer_bullets,
            ammo_reserve_dropdown,
            offer_fraction,
            cur_clip,
            max_clip
        )
        if suffix == nil then suffix = "" end

        _apply_suffix(widget, base_text, suffix)

        if bg_widget and _set_input_background_color(bg_widget, suffix ~= "") then
            bg_widget.dirty = true
        end
    end)
end

return ReassuranceSystem
