local mod = get_mod("whats_in_the_box")
local UIWidget = require("scripts/managers/ui/ui_widget")

local talent_name_lookup = {
    broker_stimm_concentration_1 = { cooldown = 6.25 },
    broker_stimm_concentration_2 = { cooldown = 6.25 },
    broker_stimm_concentration_3 = { cooldown = 6.25 },
    broker_stimm_concentration_4 = { cooldown = 6.25 },
    broker_stimm_concentration_5a = { cooldown = 25 },
    broker_stimm_concentration_5b = { cooldown_melee = 75 },
    broker_stimm_concentration_5c = { cooldown_ranged = 75 },

    broker_stimm_celerity_1 = { attack_speed = 4, weapon_swap_speed = 25 },
    broker_stimm_celerity_2 = { attack_speed = 4, weapon_swap_speed = 25, stamina_cost = -15 },
    broker_stimm_celerity_3 = { attack_speed = 4, stamina_cost = -15 },
    broker_stimm_celerity_4 = { attack_speed = 4, stamina_cost = -20 },
    broker_stimm_celerity_5a = { attack_speed = 4, stun_immunity = true, slowdown_immunity = true },
    broker_stimm_celerity_5b = { reload_speed = 30, recoil = -50 },
    broker_stimm_celerity_5c = { movement_speed = 10, dodge_distance = 10, dodge_speed = 10, dodge_recovery_speed = 10 },

    broker_stimm_durability_1 = { toughness_regen = 5, damage_taken = -4, replenish_toughness = 6.25 },
    broker_stimm_durability_2 = { toughness_regen = 5, damage_taken = -4, replenish_toughness = 6.25 },
    broker_stimm_durability_3 = { toughness_regen = 5, damage_taken = -4, replenish_toughness = 6.25 },
    broker_stimm_durability_4 = { toughness_regen = 5, damage_taken = -4, replenish_toughness = 6.25 },
    broker_stimm_durability_5a = { toughness_regen = 30 },
    broker_stimm_durability_5b = { replenish_toughness_1sec = 5 },

    broker_stimm_combat_1 = { strength = 4 },
    broker_stimm_combat_2 = { strength = 4 },
    broker_stimm_combat_3 = { strength = 4 },
    broker_stimm_combat_4a = { strength = 4, finesse = 10 },
    broker_stimm_combat_4b = { strength = 4, rending = 5 },
    broker_stimm_combat_4c = { strength = 4, crit_chance = 5 },
    broker_stimm_combat_5a = { strength = 4, finesse = 25 },
    broker_stimm_combat_5b = { strength = 4, rending = 10 },
    broker_stimm_combat_5c = { strength = 4, crit_chance = 10 },
}

local normal_stimm_effects = {
    syringe_corruption_pocketable = {
        heal = true,
    },

    syringe_ability_boost_pocketable = {
        cooldown = 300,
    },

    syringe_power_boost_pocketable = {
        strength = 25,
		rending = 25,
		pertil_generation = -33,
    },

    syringe_speed_boost_pocketable = {
        reload_speed = 15,
        attack_speed = 20,
		stamina_cost = -25,
		quell_rate = -25,
		charge_time = -25,
    },
}


local effect_defs = {
    cooldown = { setting = "show_cooldown", color = {255,255,0}, postfix = "%" },
    cooldown_melee = { setting = "show_cooldown_melee", color = {255,255,0}, postfix = "%" },
    cooldown_ranged = { setting = "show_cooldown_ranged", color = {255,255,0}, postfix = "%" },

    attack_speed = { setting = "show_attack_speed", color = {255,165,0}, postfix = "%" },
    weapon_swap_speed = { setting = "show_weapon_swap_speed", color = {255,165,0}, postfix = "%" },
    reload_speed = { setting = "show_reload_speed", color = {255,165,0}, postfix = "%" },
    recoil = { setting = "show_recoil", color = {255,165,0}, postfix = "%" },

    stamina_cost = { setting = "show_stamina_cost", color = {0,255,0}, postfix = "%" },

    movement_speed = { setting = "show_movement_speed", color = {0,255,0}, postfix = "%" },
    dodge_distance = { setting = "show_dodge_distance", color = {0,255,0}, postfix = "%" },
    dodge_speed = { setting = "show_dodge_speed", color = {0,255,0}, postfix = "%" },
    dodge_recovery_speed = { setting = "show_dodge_recovery_speed", color = {0,255,0}, postfix = "%" },

    toughness_regen = { setting = "show_toughness_regen", color = {200,128,255}, postfix = "%" },
    damage_taken = { setting = "show_damage_taken", color = {200,128,255}, postfix = "%" },
    replenish_toughness = { setting = "show_replenish_toughness", color = {200,128,255}, postfix = "%" },
	replenish_toughness_1sec = { setting = "show_replenish_toughness_1sec", color = {200,128,255}, postfix = "%" },
	pertil_generation = { setting = "show_peril_generation", color = {200,128,255}, postfix = "%" },
	quell_rate = { setting = "show_quell_rate", color = {200,128,255}, postfix = "%" },
	charge_time = { setting = "show_charge_time", color = {200,128,255}, postfix = "%" },

    strength = { setting = "show_strength", color = {255,0,128}, postfix = "%" },
    finesse = { setting = "show_finesse", color = {255,0,128}, postfix = "%" },
    rending = { setting = "show_rending", color = {255,0,128}, postfix = "%" },
    crit_chance = { setting = "show_crit_chance", color = {255,0,128}, postfix = "%" },

    stun_immunity = { setting = "show_stun_immunity", color = {255,255,255}, flag = true },
    slowdown_immunity = { setting = "show_slowdown_immunity", color = {255,255,255}, flag = true },
	
	heal = { setting = "show_heal", color = {0,255,0}, flag = true },
}

local function normalize_item_name(item)
    if not item then return nil end
    if type(item) ~= "string" then
        return tostring(item)
    end
    return string.match(item, "([^/]+)$")
end

local function get_unit_pocketable_item(unit)
    if not unit or not ALIVE[unit] then return end

    local visual_loadout_ext = ScriptUnit.has_extension(unit, "visual_loadout_system")
    if not visual_loadout_ext then return end

    local slot = visual_loadout_ext:item_from_slot("slot_pocketable_small")
    if not slot then return end

    local item_key = slot.item_name or slot.name or slot.template_name or slot.key
    return slot, item_key
end


local function is_stimm_ready(player)
	if not player or not player:unit_is_alive() then
		return false
	end

	local player_unit = player.player_unit
	if not player_unit then
		return false
	end

	local ability_extension = ScriptUnit.has_extension(player_unit, "ability_system")
	if not ability_extension then
		return false
	end

	local equipped_abilities = ability_extension:equipped_abilities()
	local pocketable_ability = equipped_abilities and equipped_abilities["pocketable_ability"]
	local has_broker_syringe = pocketable_ability and pocketable_ability.ability_group == "broker_syringe"

	if not has_broker_syringe then
		return false
	end

	local remaining_cooldown = ability_extension:remaining_ability_cooldown("pocketable_ability")
	local has_cooldown = remaining_cooldown and remaining_cooldown >= 0.05

	local buff_extension = ScriptUnit.has_extension(player_unit, "buff_system")
	if not buff_extension then
		return false
	end

	local function get_remaining_buff_time(buff_ext, template_name)
		local buffs = buff_ext._buffs_by_index
		if not buffs then
			return 0
		end

		local max_remaining = 0

		for _, buff in pairs(buffs) do
			local template = buff:template()
			if template and template.name == template_name then
				local remaining = buff:duration_progress() or 1
				local duration = buff:duration() or 15
				max_remaining = math.max(max_remaining, duration * remaining)
			end
		end

		return max_remaining
	end

	local active_buff_time = get_remaining_buff_time(buff_extension, "syringe_broker_buff")
	local has_active_buff = active_buff_time >= 0.05

	local ready = has_broker_syringe and not has_cooldown and not has_active_buff
	return ready
end

local function get_owner_active_stimm_talents(unit)
    local player = Managers.state.player_unit_spawn:owner(unit)
    if not player then return end

    local slot, stimm_key = get_unit_pocketable_item(player.player_unit)
    if not slot or not stimm_key then return end

    local totals = {}

	local key_normalized = normalize_item_name(stimm_key)
    if key_normalized == "syringe_broker_pocketable" then
        if not is_stimm_ready(player) then return end

        local profile = player:profile()
        if not profile or not profile.talents then return end

        for talent, active in pairs(profile.talents) do
            if active and talent_name_lookup[talent] then
                for effect_id, value in pairs(talent_name_lookup[talent]) do
                    if type(value) == "number" then
                        totals[effect_id] = (totals[effect_id] or 0) + value
                    elseif type(value) == "boolean" and value then
                        totals[effect_id] = true
                    end
                end
            end
        end
    else
        local effects = normal_stimm_effects[key_normalized]
        if not effects then return end

        for effect_id, value in pairs(effects) do
            totals[effect_id] = value
        end
    end

    local groups = {}
    for effect_id, amount in pairs(totals) do
        local def = effect_defs[effect_id]
        if def and mod:get(def.setting) then
            local color_key = table.concat(def.color, ",")
            groups[color_key] = groups[color_key] or {}
            table.insert(groups[color_key], {id = effect_id, amount = amount, def = def})
        end
    end

    local lines = {}

    local color_order = {
        {255,255,0},
        {255,165,0},
        {0,255,0},
        {200,128,255},
        {255,0,128},
        {255,255,255},
    }

    for _, color in ipairs(color_order) do
        local key = table.concat(color,",")
        local group = groups[key]
        if group then
            for _, eff in ipairs(group) do
                local color_val = mod:get("use_colors") and eff.def.color or {255,255,255}
                local text = mod:localize(eff.def.setting)
                if eff.amount == true or eff.def.flag then
                    table.insert(lines,
                        string.format("{#color(%d,%d,%d)}%s{#reset}", color_val[1], color_val[2], color_val[3], text)
                    )
                else
                    table.insert(lines,
                        string.format("{#color(%d,%d,%d)}%s %+g%s{#reset}", color_val[1], color_val[2], color_val[3], text, eff.amount, eff.def.postfix or "")
                    )
                end
            end
        end
    end

    return #lines > 0 and table.concat(lines, "\n") or nil
end


local StimmFieldMarker = {
    name = "stimm_field_marker",
    size = {2000, 2000},
    max_distance = mod:get("show_distance"),
    position_offset = {0,0,1},
}

function StimmFieldMarker.create_widget_defintion(template, scenegraph_id)
    return UIWidget.create_definition({
        {
            value_id = "talent_text",
            style_id = "talent_text",
            pass_type = "text",
            value = "<talent_text>",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
				font_type = mod:get("font_type") or "proxima_nova_bold",
                font_size = mod:get("font_size") or 20,
                text_color = {255,255,255,255},
                default_text_color = {255,255,255,255},
                offset = {0,0,0},
                size = StimmFieldMarker.size
            },
            visibility_function = function() return true end
        }
    }, scenegraph_id)
end

function StimmFieldMarker.on_enter(widget, marker, template)
    marker.draw = true

    local distance = tonumber(mod:get("show_distance")) or 10
    marker.max_distance = distance
    if template then
        template.max_distance = distance
    end

    local unit = marker.unit
    if unit and mod._stimm_field_text_cache and mod._stimm_field_text_cache[unit] then
        marker.talents_text = mod._stimm_field_text_cache[unit]
        if widget and widget.content then
            widget.content.talent_text = marker.talents_text
        end
    end
end

function StimmFieldMarker.update_function(parent, ui_renderer, widget, marker, template, dt, t)
    if not widget or not widget.content then return end
    widget.content.talent_text = marker.talents_text or ""
end

mod:hook_safe("HudElementWorldMarkers", "init", function(self)
    self._marker_templates[StimmFieldMarker.name] = StimmFieldMarker
end)

mod.on_all_mods_loaded = function()
	local is_mod_loading = true
	
	mod:hook_require("scripts/extension_systems/unit_templates", function(instance)
		if is_mod_loading then
			local function handle_unit(unit)
				if not unit then return end
				local talents_str = get_owner_active_stimm_talents(unit)
				mod._stimm_field_text_cache = mod._stimm_field_text_cache or {}
				mod._stimm_field_text_cache[unit] = talents_str
				Managers.event:trigger("add_world_marker_unit", StimmFieldMarker.name, unit)
			end

			local template = instance.broker_stimm_field_crate_deployable
			if template then
				mod:hook_safe(template, "husk_init", handle_unit)
				mod:hook_safe(template, "local_init", handle_unit)
			end
		end	
		is_mod_loading = false
	end)
end