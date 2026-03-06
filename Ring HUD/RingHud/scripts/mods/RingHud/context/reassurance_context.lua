-- File: RingHud/scripts/mods/RingHud/context/reassurance_context.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local ReassuranceSystem     = {}

local Pickups               = require("scripts/settings/pickup/pickups")
local UISettings            = require("scripts/settings/ui/ui_settings")
local Color                 = require("scripts/utilities/ui/colors")
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
-- Font handling:
-- We cannot apply different font_type per substring via markup (only color/size/reset),
-- so we apply machine_medium to the whole widget ONLY while our wastage suffix is shown,
-- and restore the original font when not shown. We also bump font_size slightly.
----------------------------------------------------------------
local function _update_base_font_if_inactive(widget)
    if not (widget and widget.style and widget.content) then return end
    if widget.content._ringhud_machine_medium_active then
        return
    end

    widget.content._ringhud_base_fonts = widget.content._ringhud_base_fonts or {}
    local base = widget.content._ringhud_base_fonts

    local function capture(key)
        local s = widget.style[key]
        if s then
            base[key] = base[key] or {}
            base[key].font_type = s.font_type
            base[key].font_size = s.font_size
        end
    end

    capture("text")
    capture("text_style")
end

local function _apply_machine_medium_with_bump(widget)
    if not (widget and widget.style and widget.content) then return false end

    _update_base_font_if_inactive(widget)

    local base = widget.content._ringhud_base_fonts
    if not base then return false end

    local did  = false
    local bump = 2

    local function apply(key)
        local s = widget.style[key]
        local b = base[key]
        if not (s and b) then return end

        if s.font_type ~= "machine_medium" then
            s.font_type = "machine_medium"
            did = true
        end

        local base_size = tonumber(b.font_size) or tonumber(s.font_size) or 20
        local want_size = base_size + bump

        if type(s.font_size) ~= "number" or s.font_size ~= want_size then
            s.font_size = want_size
            did = true
        end
    end

    apply("text")
    apply("text_style")

    widget.content._ringhud_machine_medium_active = true
    return did
end

local function _restore_base_font(widget)
    if not (widget and widget.style and widget.content) then return false end
    if not widget.content._ringhud_machine_medium_active then return false end

    local base = widget.content._ringhud_base_fonts
    if not base then
        widget.content._ringhud_machine_medium_active = nil
        return false
    end

    local did = false

    local function restore(key)
        local s = widget.style[key]
        local b = base[key]
        if not (s and b) then return end

        if b.font_type and s.font_type ~= b.font_type then
            s.font_type = b.font_type
            did = true
        end

        if b.font_size and s.font_size ~= b.font_size then
            s.font_size = b.font_size
            did = true
        end
    end

    restore("text")
    restore("text_style")

    widget.content._ringhud_machine_medium_active = nil
    return did
end

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
    if not interactee_player then
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
        if widget then
            _update_base_font_if_inactive(widget)
        end

        -- Ammo wastage text: only when NumericUI is NOT installed and minimal objective feed is enabled
        if local_mod._numeric_ui_installed
            or not (local_mod._settings and local_mod._settings.minimal_objective_feed_enabled)
        then
            if widget then
                local base = _strip_previous_suffix(widget)
                _apply_suffix(widget, base, "")
                if _restore_base_font(widget) then
                    widget.dirty = true
                end
            end
            return
        end

        -- Respect: ammo_reserve_disabled => no wastage text at all
        local ammo_reserve_dropdown = local_mod._settings and local_mod._settings.ammo_reserve_dropdown
        if ammo_reserve_dropdown == "ammo_reserve_disabled" then
            if widget then
                local base = _strip_previous_suffix(widget)
                _apply_suffix(widget, base, "")
                if _restore_base_font(widget) then
                    widget.dirty = true
                end
            end
            return
        end

        -- Only compute wastage for: small clip, large clip, deployable ammo crate
        local pickup_name = WASTAGE_PICKUP_BY_LOC[hud_description]
        if not pickup_name or not widget then
            if widget then
                local base = _strip_previous_suffix(widget)
                _apply_suffix(widget, base, "")
                if _restore_base_font(widget) then
                    widget.dirty = true
                end
            end
            return
        end

        -- Strip any previous suffix first (so we can re-append updated value cleanly)
        local base_text = _strip_previous_suffix(widget)

        local player = Managers.player:local_player_safe(1)
        local unit = player and player.player_unit
        if not (unit and Unit.alive(unit)) then
            _apply_suffix(widget, base_text, "")
            if _restore_base_font(widget) then widget.dirty = true end
            return
        end

        local unit_data_ext = ScriptUnit.has_extension(unit, "unit_data_system")
            and ScriptUnit.extension(unit, "unit_data_system")
        if not unit_data_ext then
            _apply_suffix(widget, base_text, "")
            if _restore_base_font(widget) then widget.dirty = true end
            return
        end

        -- Secondary slot only (RingHud's ammo reserve feature is secondary slot-based)
        local component = unit_data_ext:read_component("slot_secondary")
        if not component then
            _apply_suffix(widget, base_text, "")
            if _restore_base_font(widget) then widget.dirty = true end
            return
        end

        local cur_res = U.sum_ammo_field(component.current_ammunition_reserve)
        local max_res = U.sum_ammo_field(component.max_ammunition_reserve)

        if not (max_res and max_res > 0) then
            _apply_suffix(widget, base_text, "")
            if _restore_base_font(widget) then widget.dirty = true end
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
            _apply_suffix(widget, base_text, "")
            if _restore_base_font(widget) then widget.dirty = true end
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

        -- Offer bullets in terms of RESERVE for wastage calculations.
        -- For deployable ammo crate, pass max_ammo_clip=0 so the “100%” concept is reserve-only.
        local offer_bullets = ammo_amount_func(max_res, 0, pickup_data) or 0
        offer_bullets = math.floor(offer_bullets + 0.5)

        if offer_bullets <= 0 then
            _apply_suffix(widget, base_text, "")
            if _restore_base_font(widget) then widget.dirty = true end
            return
        end

        if type(local_mod.ammo_reserve_wastage_string_for_offer) ~= "function" then
            _apply_suffix(widget, base_text, "")
            if _restore_base_font(widget) then widget.dirty = true end
            return
        end

        local suffix = local_mod.ammo_reserve_wastage_string_for_offer(
            cur_res,
            max_res,
            offer_bullets,
            ammo_reserve_dropdown,
            offer_fraction
        )
        if suffix == nil then suffix = "" end

        -- If we are showing our suffix, apply machine_medium (cannot apply per-substring);
        -- otherwise restore base font.
        if suffix ~= "" then
            if _apply_machine_medium_with_bump(widget) then
                widget.dirty = true
            end
        else
            if _restore_base_font(widget) then
                widget.dirty = true
            end
        end

        _apply_suffix(widget, base_text, suffix)
    end)
end

return ReassuranceSystem
