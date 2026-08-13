-- File: scripts/mods/SimpleBuffFilter/runtime/debug.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return end
--[[
debug.lua – lightweight debug utilities: colored rule markers/labels.
]]
-- Depends on:
--   • util/colors.lua     (tint helpers)

local Colors = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/colors")

mod.tbf_debug = mod.tbf_debug or {}

-- ---------------------------------------------------------------------------
-- Tinted labels
-- ---------------------------------------------------------------------------

local RULE_LOC = {
    allow              = "loc_settings_menu_group_display",
    hide               = "loc_social_menu_player_blocked",
    hide_if_selected   = "loc_setting_notification_type_others",
    cooldown_only      = "loc_door_interlude",
    only_in_psykhanium = "loc_training_grounds_view_intro_title",
}

function mod.tbf_debug.rule_label(rule)
    local key  = RULE_LOC[rule]
    local base = key and mod:localize(key) or tostring(rule)
    return Colors.tint_rule(base, rule)
end

function mod.tbf_debug.mark_show()
    return Colors.tint_text("SHOW", Colors.color_arr("ui_green_light"))
end

function mod.tbf_debug.mark_hide()
    return Colors.tint_text("HIDE", Colors.color_arr("ui_red_light"))
end

function mod.tbf_debug.mark_allow()
    return Colors.tint_text("ALLOW", Colors.color_arr("ui_green_light"))
end
