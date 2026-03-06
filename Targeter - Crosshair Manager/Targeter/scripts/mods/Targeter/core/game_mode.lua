-- File: Targeter/scripts/mods/Targeter/core/game_mode.lua
local mod = get_mod("Targeter")
if not mod then return end

mod:hook_safe(CLASS.GameModeManager, "init", function(self, game_mode_context, game_mode_name, ...)
    mod.game_mode_is_hub = (game_mode_name == "hub")

    mod.crosshair_state = "default"
    mod._carried_ranged_template = nil
    mod._carried_ranged_class = nil
    mod._uses_overheat_current = nil
    mod._next_trace_t = 0
    mod._ads_poll_active = false
    mod._ads_state = { last_true_t = 0, started_by = nil }

    mod._is_zealot_knives = mod.has_zealot_throwing_knives()

    local class_now = mod.current_carried_ranged_weapon_class()
    if class_now then
        mod._carried_ranged_class = class_now
    end
end)
