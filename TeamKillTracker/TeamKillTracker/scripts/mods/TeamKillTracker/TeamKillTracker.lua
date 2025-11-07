local mod = get_mod("TeamKillTracker")

local Breed = mod:original_require("scripts/utilities/breed")

local hud_elements = {
	{
		filename = "TeamKillTracker/scripts/mods/TeamKillTracker/HudElementPlayerStats",
		class_name = "HudElementPlayerStats",
		visibility_groups = {
			"alive",
		},
	},
}

mod.player_kills = {}
mod.player_damage = {}
mod.killed_units = {}
mod.current_health = {}

for _, hud_element in ipairs(hud_elements) do
	mod:add_require_path(hud_element.filename)
end

mod:hook("UIHud", "init", function(func, self, elements, visibility_groups, params)
	for _, hud_element in ipairs(hud_elements) do
		if not table.find_by_key(elements, "class_name", hud_element.class_name) then
			table.insert(elements, {
				class_name = hud_element.class_name,
				filename = hud_element.filename,
				use_hud_scale = true,
				visibility_groups = hud_element.visibility_groups or {
					"alive",
				},
			})
		end
	end

	return func(self, elements, visibility_groups, params)
end)

mod._is_in_hub = function()
	local game_mode_name = Managers.state.game_mode:game_mode_name()
	return game_mode_name == "hub"
end

local function recreate_hud()
    mod.player_kills = {}
    mod.player_damage = {}
    mod.killed_units = {}
    mod.current_health = {}
    mod.hide_team_kills = mod:get("hide_team_kills")
    mod.hide_user_kills = mod:get("hide_user_kills")
    mod.hud_counter_mode = mod:get("hud_counter_mode") or 1
end

mod.on_all_mods_loaded = function()
	recreate_hud()
end

mod.on_setting_changed = function()
    mod.hide_team_kills = mod:get("hide_team_kills")
    mod.hide_user_kills = mod:get("hide_user_kills")
    mod.hud_counter_mode = mod:get("hud_counter_mode") or 1
end

function mod.on_game_state_changed(status, state_name)
	if state_name == 'GameplayStateRun' or state_name == "StateGameplay" and status == "enter" then
		recreate_hud()
	end
end

mod.add_to_killcounter = function(account_id)
    if not account_id then
		return
	end
	
    if not mod.player_kills[account_id] then
        mod.player_kills[account_id] = 0
	end
	
    mod.player_kills[account_id] = mod.player_kills[account_id] + 1
end

mod.add_to_damage = function(account_id, amount)
    if not account_id or not amount then
        return
    end
    if not mod.player_damage[account_id] then
        mod.player_damage[account_id] = 0
    end
    mod.player_damage[account_id] = mod.player_damage[account_id] + math.max(0, amount)
end

-- Получаем игрока по юниту (проверяем всех игроков)
mod.player_from_unit = function(self, unit)
	if unit then
		local player_manager = Managers.player
		local players = player_manager:players()
		for _, player in pairs(players) do
			if player and player.player_unit == unit then
				return player
			end
		end
	end
	return nil
end

mod:hook_safe(CLASS.AttackReportManager, "add_attack_result",
function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage,
	attack_result, attack_type, damage_efficiency, ...)

    local player = mod:player_from_unit(attacking_unit)
    if player then
        local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
        local breed_or_nil = unit_data_extension and unit_data_extension:breed()
        local target_is_minion = breed_or_nil and Breed.is_minion(breed_or_nil)
        if target_is_minion then
            local account_id = player:account_id() or player:name() or "Player"

            -- Подсчет урона (как в scoreboard): фактический + overkill
            local current_health = mod.current_health[attacked_unit]
            local unit_health_extension = ScriptUnit.has_extension(attacked_unit, "health_system")
            local new_health = unit_health_extension and unit_health_extension:current_health()

            local dealt = damage or 0
            local actual_damage = dealt
            local overkill_damage = 0

            if attack_result == "damaged" then
                if not current_health then
                    current_health = (new_health or 0) + dealt
                end
                actual_damage = math.min(dealt, current_health)
                mod.current_health[attacked_unit] = new_health

            elseif attack_result == "died" then
                if not current_health then
                    current_health = dealt
                end
                actual_damage = current_health
                overkill_damage = dealt - actual_damage
                mod.current_health[attacked_unit] = nil

                -- Килл: считаем один раз на юнит
                if not mod.killed_units[attacked_unit] then
                    mod.killed_units[attacked_unit] = true
                    mod.add_to_killcounter(account_id)
                end
            end

            local total_damage = (actual_damage or 0) + (overkill_damage or 0)
            if total_damage > 0 then
                mod.add_to_damage(account_id, total_damage)
            end
        end
    end
end)

