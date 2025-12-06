-- File: RingHud/scripts/mods/RingHud/features/ability_sound_feature.lua
local mod = get_mod("RingHud")
if not mod then return {} end

-- Public namespace (cross-file): attach to `mod.` per your rule.
mod.ability_sound        = mod.ability_sound or {}
local F                  = mod.ability_sound

--=====================================================================--
-- Config & helpers
--=====================================================================--
-- Events:
-- • NEW_ABILITY_SOUND: Zealot bolstering prayer (RingHud’s preferred cue).
-- • SHIELD_ABILITY_SOUND: Blunt shield impact.
-- • ITEM_TIER3_SOUND: UI item result overlay tier 3.
-- • ORIGINAL_ABILITY_SOUND: vanilla HUD “off cooldown” ping.
F.NEW_ABILITY_SOUND      = "wwise/events/player/play_ability_zealot_bolstering_prayer"
F.SHIELD_ABILITY_SOUND   = "wwise/events/weapon/melee_hits_blunt_shield"
F.ITEM_TIER3_SOUND       = "wwise/events/ui/play_ui_item_result_ovelay_tier_3"
F.ORIGINAL_ABILITY_SOUND = "wwise/events/ui/play_hud_ability_off_cooldown"

-- mode: "default" | "zealot" | "shield" | "item_tier3"
local function _current_mode()
    return (mod._settings and mod._settings.timer_sound_enabled) or "zealot"
end

-- Resolve which RingHud sound to request, if we are handling it ourselves.
-- Returns:
--   • nil      → do not request a custom sound (used only when AAR is absent).
--   • event id → one of the constants above.
function F.resolve_selected_sound()
    local mode = _current_mode()

    if mode == "default" then
        -- In default mode (without AAR) we hand control back to vanilla, so
        -- we do not request a custom sound here.
        return nil
    elseif mode == "shield" then
        return F.SHIELD_ABILITY_SOUND
    elseif mode == "item_tier3" then
        return F.ITEM_TIER3_SOUND
    else
        -- Treat anything else (including "zealot" and legacy values) as zealot.
        return F.NEW_ABILITY_SOUND
    end
end

-- AAR-aware sound pick (if AAR exported two different events for 1/2 charges)
function F.pick_aar_sound_by_charges(charges)
    local s1 = mod._aar_sound_1 or F.ORIGINAL_ABILITY_SOUND
    local s2 = mod._aar_sound_2 or s1
    return (charges == 2) and s2 or s1
end

-- Centralized play that defers to AAR’s injector when present
function F.play_ready_sound(event_name, self_or_nil)
    if not event_name or event_name == "" then
        return false
    end

    local is_aar_event = (event_name == (mod._aar_sound_1 or "")) or (event_name == (mod._aar_sound_2 or ""))
    if mod._aar_present and is_aar_event then
        if mod._aar_play_event then
            return mod._aar_play_event(event_name)
        else
            return false
        end
    end

    if self_or_nil and self_or_nil._play_sound then
        self_or_nil:_play_sound(event_name)
        return true
    end

    return false
end

--=====================================================================--
-- Hooks
--  NOTE: Per-project rule “one hook per function per mod” — ensure these
--  are the only hooks for the functions below across RingHud.
--=====================================================================--

-- HudElementPlayerSlotItemAbility:init
-- (Used only to emit a “ready” cue on first widget init when AAR is NOT present.)
mod:hook(CLASS.HudElementPlayerSlotItemAbility, "init", function(func, self, parent, draw_layer, start_scale, data)
    -- If AAR is present, do not override vanilla at all (and don’t play here).
    if mod._aar_present then
        return func(self, parent, draw_layer, start_scale, data)
    end

    -- Vanilla body with swapped definition loading
    local definition_path = data.definition_path
    local definitions = dofile(definition_path)

    HudElementPlayerSlotItemAbility.super.init(self, parent, draw_layer, start_scale, definitions)

    self._data                     = data
    self._slot_id                  = data.slot_id

    local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
    local slot_configuration       = PlayerCharacterConstants.slot_configuration
    local slot_config              = slot_configuration[self._slot_id]
    local wield_inputs             = slot_config and slot_config.wield_inputs
    self._wield_input              = wield_inputs and wield_inputs[1]

    self:_set_progress(1)
    self:set_charges_amount()
    self:set_icon(data.icon)

    local on_cooldown      = false
    local uses_charges     = false
    local has_charges_left = true

    self:_set_widget_state_colors(on_cooldown, uses_charges, has_charges_left)
    self:_update_input()
    self:_register_events()

    -- One-time “ready” cue on first init (mode-based, only when RingHud owns sounds).
    local mode = _current_mode()
    if mode ~= "default" then
        local event = F.resolve_selected_sound()
        if event then
            F.play_ready_sound(event, self)
        end
    end
end)

-- HudElementPlayerAbility:update
mod:hook(CLASS.HudElementPlayerAbility, "update",
    function(func, self, dt, t, ui_renderer, render_settings, input_service)
        local mode = _current_mode()

        -- If user selected "default" and Audible Ability Recharge is NOT present,
        -- let the vanilla method (and its own ability_off_cooldown sound) run
        -- completely unaltered.
        if mode == "default" and not mod._aar_present then
            return func(self, dt, t, ui_renderer, render_settings, input_service)
        end

        -- Otherwise, we run a copy of vanilla update but redirect the sound call:
        --   • If AAR is present → use AAR-provided events (per-ability/per-slot).
        --   • If AAR is not present → use our dropdown selection (zealot/shield/etc.).
        HudElementPlayerAbility.super.update(self, dt, t, ui_renderer, render_settings, input_service)

        local player                          = self._data.player
        local parent                          = self._parent
        local ability_extension               = parent and parent.get_player_extension
            and parent:get_player_extension(player, "ability_system")
        local ability_id                      = self._ability_id

        local cooldown_progress
        local remaining_ability_charges
        local has_charges_left                = true
        local uses_charges                    = false
        local in_process_of_going_on_cooldown = false -- kept for parity
        local force_on_cooldown               = false -- kept for parity

        if ability_extension and ability_extension:ability_is_equipped(ability_id) then
            local remaining_ability_cooldown = ability_extension:remaining_ability_cooldown(ability_id)
            local max_ability_cooldown       = ability_extension:max_ability_cooldown(ability_id)
            local is_paused                  = ability_extension:is_cooldown_paused(ability_id)

            remaining_ability_charges        = ability_extension:remaining_ability_charges(ability_id)
            local max_ability_charges        = ability_extension:max_ability_charges(ability_id)

            uses_charges                     = max_ability_charges and max_ability_charges > 1
            has_charges_left                 = (remaining_ability_charges or 0) > 0

            if is_paused then
                cooldown_progress = 0
            elseif max_ability_cooldown and max_ability_cooldown > 0 then
                cooldown_progress = 1 - math.lerp(0, 1, remaining_ability_cooldown / max_ability_cooldown)

                if cooldown_progress == 0 then
                    cooldown_progress = 1
                end
            else
                cooldown_progress = uses_charges and 1 or 0
            end
        end

        if cooldown_progress ~= self._ability_progress then
            self:_set_progress(cooldown_progress)
        end

        local on_cooldown = cooldown_progress ~= 1 and not in_process_of_going_on_cooldown or force_on_cooldown

        if on_cooldown ~= self._on_cooldown
            or uses_charges ~= self._uses_charges
            or has_charges_left ~= self._has_charges_left
        then
            -- Edge: JUST became ready (cooldown finished) and we still have charges if charges are used.
            if not on_cooldown and self._on_cooldown and (not uses_charges or has_charges_left) then
                if mod._aar_present then
                    -- AAR-present path: delegate to AAR’s events for 1/2 charges.
                    local event = F.pick_aar_sound_by_charges(remaining_ability_charges or 1)
                    F.play_ready_sound(event, self)
                else
                    -- RingHud-owned sound: use dropdown mode (zealot / shield / item_tier3).
                    local event = F.resolve_selected_sound()
                    if event then
                        F.play_ready_sound(event, self)
                    end
                end
            end

            self._on_cooldown      = on_cooldown
            self._uses_charges     = uses_charges
            self._has_charges_left = has_charges_left

            self:_set_widget_state_colors(on_cooldown, uses_charges, has_charges_left)
        end

        if remaining_ability_charges and remaining_ability_charges ~= self._remaining_ability_charges then
            self._remaining_ability_charges = remaining_ability_charges
            self:set_charges_amount(uses_charges and remaining_ability_charges)
        end
    end)

return F
