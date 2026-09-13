local mod = get_mod("CustomCharacterBots")

if mod.set_internal_data then
	mod:set_internal_data("allow_rehooking", true)
end

local profiles_cache = {}
local selected_profile_id = nil
local fetch_in_progress = false
local profiles_ready = false
local bot_swap_count = 0
local bot_hooks_registered = false
local last_swap_t = -math.huge
local auto_fetch_next_t = 0
local auto_fetch_last_success_t = -math.huge
local auto_fetch_last_game_mode = nil
local auto_fetch_frontend_ready_t = nil
local auto_reset_last_game_mode = nil
local used_profile_ids = {}
local weapon_template_hook_registered = false

local WEAPON_TEMPLATES_PATH = "scripts/settings/equipment/weapon_templates/weapon_templates"
local AUTO_FETCH_RETRY_DELAY = 5
local AUTO_FETCH_BACKEND_RETRY_DELAY = 15
local AUTO_FETCH_FRONTEND_STARTUP_DELAY = 15
local AUTO_FETCH_REFRESH_DELAY = 300

local DEFAULT_BOT_GESTALTS = {
	melee = "linesman",
	ranged = "killshot",
}

local ok_weapon_action_shoot, WeaponActionShoot = pcall(function()
	return mod:io_dofile("CustomCharacterBots/scripts/mods/CustomCharacterBots/ccb_weapon_action_shoot")
end)

if not ok_weapon_action_shoot then
	local err = WeaponActionShoot
	WeaponActionShoot = nil
	mod:warning("Custom Character Bots: weapon action shoot helper failed to load: %s", tostring(err))
end

local ok_sustained_fire, SustainedFire = pcall(function()
	return mod:io_dofile("CustomCharacterBots/scripts/mods/CustomCharacterBots/ccb_sustained_fire")
end)

if not ok_sustained_fire then
	local err = SustainedFire
	SustainedFire = nil
	mod:warning("Custom Character Bots: sustained-fire helper failed to load: %s", tostring(err))
end

local ok_weapon_special_action, WeaponSpecialAction = pcall(function()
	return mod:io_dofile("CustomCharacterBots/scripts/mods/CustomCharacterBots/ccb_weapon_special_action")
end)

if not ok_weapon_special_action then
	local err = WeaponSpecialAction
	WeaponSpecialAction = nil
	mod:warning("Custom Character Bots: weapon-special helper failed to load: %s", tostring(err))
end

local ok_bot_vo_support, BotVoSupport = pcall(function()
	return mod:io_dofile("CustomCharacterBots/scripts/mods/CustomCharacterBots/ccb_bot_vo_support")
end)

if not ok_bot_vo_support then
	local err = BotVoSupport
	BotVoSupport = nil
	mod:warning("Custom Character Bots: bot VO helper failed to load: %s", tostring(err))
end

local PlayerlikeBehaviorLoadError = nil
local ok_playerlike_behavior, PlayerlikeBehavior = pcall(function()
	return mod:io_dofile("CustomCharacterBots/scripts/mods/CustomCharacterBots/ccb_playerlike_behavior")
end)

if not ok_playerlike_behavior then
	local err = PlayerlikeBehavior
	PlayerlikeBehaviorLoadError = tostring(err)
	PlayerlikeBehavior = nil
	mod:warning("Custom Character Bots: player-like behavior helper failed to load: %s", tostring(err))
end

local ok_behavior_learning, BehaviorLearning = pcall(function()
	return mod:io_dofile("CustomCharacterBots/scripts/mods/CustomCharacterBots/ccb_behavior_learning")
end)

if not ok_behavior_learning then
	local err = BehaviorLearning
	BehaviorLearning = nil
	mod:warning("Custom Character Bots: behavior learning helper failed to load: %s", tostring(err))
end

local CORE_ARCHETYPES = {
	ogryn = true,
	psyker = true,
	veteran = true,
	zealot = true,
}

local SAFE_BOT_PROFILE_BY_ARCHETYPE = {
	ogryn = "darktide_seven_02",
	psyker = "darktide_seven_04",
	veteran = "high_bot_1",
	zealot = "tutorial_guide_zealot",
}

local COMBAT_SLOTS = {
	"slot_primary",
	"slot_secondary",
}

local function table_has_keyword(target, keyword)
	for _, value in ipairs(target and target.keywords or {}) do
		if value == keyword then
			return true
		end
	end

	return false
end

local function action_inputs_table(weapon_template)
	local action_inputs = weapon_template and weapon_template.action_inputs

	return type(action_inputs) == "table" and action_inputs or nil
end

local function actions_table(weapon_template)
	local actions = weapon_template and weapon_template.actions

	return type(actions) == "table" and actions or nil
end

local function is_valid_action_input(weapon_template, input_name)
	return type(input_name) == "string" and action_inputs_table(weapon_template) and action_inputs_table(weapon_template)[input_name] ~= nil
end

local function find_action_for_input(weapon_template, input_name)
	for action_name, action in pairs(actions_table(weapon_template) or {}) do
		if action.start_input == input_name then
			return action_name
		end
	end

	return nil
end

local function find_chained_action_for_input(weapon_template, input_name)
	for _, action in pairs(actions_table(weapon_template) or {}) do
		local chain = action.allowed_chain_actions and action.allowed_chain_actions[input_name]

		if chain and chain.action_name then
			return chain.action_name
		end
	end

	return nil
end

local function find_fire_input(weapon_template)
	local candidates = {}

	for input_name, input_def in pairs(action_inputs_table(weapon_template) or {}) do
		local first = input_def.input_sequence and input_def.input_sequence[1]

		if first and first.input == "action_one_pressed" and first.value == true and not first.hold_input then
			local action_name = find_action_for_input(weapon_template, input_name)

			if action_name then
				candidates[#candidates + 1] = {
					input_name = input_name,
					action_name = action_name,
				}
			end
		end
	end

	if #candidates == 0 then
		return nil, nil
	end

	for _, preferred in ipairs({ "shoot_pressed", "shoot_charge", "shoot" }) do
		for _, candidate in ipairs(candidates) do
			if candidate.input_name == preferred then
				return candidate.input_name, candidate.action_name
			end
		end
	end

	return candidates[1].input_name, candidates[1].action_name
end

local function find_aim_fire_input(weapon_template)
	for input_name, input_def in pairs(action_inputs_table(weapon_template) or {}) do
		local first = input_def.input_sequence and input_def.input_sequence[1]

		if first and first.input == "action_one_pressed" and first.value == true and first.hold_input == "action_two_hold" then
			return input_name, find_action_for_input(weapon_template, input_name) or find_chained_action_for_input(weapon_template, input_name)
		end
	end

	for input_name, input_def in pairs(action_inputs_table(weapon_template) or {}) do
		local first = input_def.input_sequence and input_def.input_sequence[1]

		if first and first.input == "action_one_hold" and first.value == true then
			return input_name, find_action_for_input(weapon_template, input_name) or find_chained_action_for_input(weapon_template, input_name)
		end
	end

	return nil, nil
end

local function build_ranged_bot_meta(weapon_template)
	if weapon_template.name == "ogryn_gauntlet_p1_m1" then
		return {
			fire_action_input = "zoom_shoot",
			fire_action_name = "action_shoot_zoomed",
			aim_action_input = "zoom",
			aim_action_name = "action_zoom",
			unaim_action_input = "zoom_release",
			unaim_action_name = "action_unzoom",
			aim_fire_action_input = "zoom_shoot",
			aim_fire_action_name = "action_shoot_zoomed",
			max_range = 28,
			aim_at_node = "j_spine",
			ignore_allies_for_obstruction = true,
		}
	end

	if weapon_template.name and string.find(weapon_template.name, "^lasgun_p2_") then
		return {
			fire_action_input = "shoot_release_charged",
			fire_action_name = "action_shoot_hip_charged",
			aim_action_input = "zoom",
			aim_action_name = "action_zoom",
			unaim_action_input = "zoom_release",
			unaim_action_name = "action_unzoom",
			aim_fire_action_input = "zoom_shoot_release_charged",
			aim_fire_action_name = "action_zoom_shoot_charged",
			can_charge_shot = true,
			charge_action_input = "zoom_shoot_hold",
			always_charge_before_firing = true,
			minimum_charge_time = 0.2,
			charge_shot_delay = 0.05,
			max_range = 45,
			max_range_charged = 60,
			aim_at_node = { "j_head", "j_spine" },
		}
	end

	local actions = actions_table(weapon_template) or {}
	local attack_meta_data = type(weapon_template.attack_meta_data) == "table" and weapon_template.attack_meta_data or {}
	local attack_action = actions[attack_meta_data.fire_action_name or "action_shoot"] or {}
	local aim_attack_action = actions[attack_meta_data.aim_fire_action_name or "action_shoot_zoomed"] or {}
	local fallback_fire_input = attack_meta_data.fire_action_input or attack_action.start_input or "shoot"
	local fallback_aim_fire_input = attack_meta_data.aim_fire_action_input or aim_attack_action.start_input or "zoom_shoot"
	local corrections = {}
	local changed = false

	if not is_valid_action_input(weapon_template, fallback_fire_input) then
		local fire_input, fire_action = find_fire_input(weapon_template)

		if fire_input then
			corrections.fire_action_input = fire_input

			if not actions.action_shoot then
				corrections.fire_action_name = fire_action
			end

			changed = true
		end
	end

	local effective_fire_input = corrections.fire_action_input or fallback_fire_input

	if not is_valid_action_input(weapon_template, fallback_aim_fire_input) and is_valid_action_input(weapon_template, effective_fire_input) then
		corrections.aim_fire_action_input = effective_fire_input
		changed = true
	end

	local aim_fire_input, aim_fire_action = find_aim_fire_input(weapon_template)

	if aim_fire_input and attack_meta_data.aim_fire_action_input ~= aim_fire_input then
		corrections.aim_fire_action_input = aim_fire_input
		corrections.aim_fire_action_name = aim_fire_action
		changed = true
	end

	if attack_meta_data.aim_at_node == nil and (
		table_has_keyword(weapon_template, "lasgun")
		or table_has_keyword(weapon_template, "autogun")
		or table_has_keyword(weapon_template, "bolter")
		or table_has_keyword(weapon_template, "stub_pistol")
	) then
		corrections.aim_at_node = { "j_head", "j_spine" }
		changed = true
	end

	return changed and corrections or nil
end

local function patch_saved_loadout_weapon_templates(WeaponTemplates)
	if type(WeaponTemplates) ~= "table" then
		return
	end

	local injected = 0
	local patched = 0

	for _, weapon_template in pairs(WeaponTemplates) do
		if type(weapon_template) == "table" and table_has_keyword(weapon_template, "ranged") then
			local corrections = build_ranged_bot_meta(weapon_template)

			if corrections then
				if type(weapon_template.attack_meta_data) == "table" then
					for key, value in pairs(corrections) do
						weapon_template.attack_meta_data[key] = value
					end

					patched = patched + 1
				else
					weapon_template.attack_meta_data = corrections
					injected = injected + 1
				end
			end
		end
	end

	if mod:get("detailed_logging") then
		mod:info(
			"Saved loadout ranged weapon compatibility installed: injected=%d patched=%d",
			injected,
			patched
		)
	end
end

local function hook_require_now(path, callback)
	mod:hook_require(path, callback)

	local loaded = package.loaded and package.loaded[path]

	if loaded ~= nil and loaded ~= false then
		local ok, err = pcall(callback, loaded)

		if not ok then
			mod:warning("Custom Character Bots: cached require hook failed for %s: %s", tostring(path), tostring(err))
		end
	end
end

local function register_weapon_template_hooks()
	if weapon_template_hook_registered then
		return
	end

	weapon_template_hook_registered = true

	hook_require_now(WEAPON_TEMPLATES_PATH, function(WeaponTemplates)
		patch_saved_loadout_weapon_templates(WeaponTemplates)
	end)
end

local function fixed_time()
	local ok, FixedFrame = pcall(require, "scripts/utilities/fixed_frame")

	if ok and FixedFrame and FixedFrame.get_latest_fixed_time then
		local frame_ok, result = pcall(FixedFrame.get_latest_fixed_time)

		if frame_ok and result then
			return result
		end
	end

	return os.clock()
end

local function safe_clock()
	return os.clock()
end

local function betterbots_active()
	local get_mod_fn = rawget(_G, "get_mod")

	if not get_mod_fn then
		return false
	end

	local ok, betterbots = pcall(get_mod_fn, "BetterBots")

	return ok and betterbots ~= nil
end

local function tertium_active()
	local get_mod_fn = rawget(_G, "get_mod")

	if not get_mod_fn then
		return false
	end

	local ok_t5, tertium4or5 = pcall(get_mod_fn, "Tertium4Or5")

	if ok_t5 and tertium4or5 ~= nil then
		return true
	end

	local ok_t6, tertium6 = pcall(get_mod_fn, "Tertium6")

	return ok_t6 and tertium6 ~= nil
end

local function tertium_mod()
	local get_mod_fn = rawget(_G, "get_mod")

	if not get_mod_fn then
		return nil
	end

	local ok_t5, tertium4or5 = pcall(get_mod_fn, "Tertium4Or5")

	if ok_t5 and tertium4or5 ~= nil then
		return tertium4or5
	end

	local ok_t6, tertium6 = pcall(get_mod_fn, "Tertium6")

	return ok_t6 and tertium6 or nil
end

local function betterbots_compat_enabled()
	return mod:get("prefer_betterbots_behavior") ~= false and betterbots_active()
end

local function experimental_features_enabled()
	return mod:get("enable_experimental_features") == true
end

local function behavior_learning_enabled()
	return experimental_features_enabled() and mod:get("enable_behavior_learning") == true
end

local alive_ccb_bot_lines
local saved_weapon_compat_enabled

local CCB_DEBUG_OUTPUT_DIRS = {
	"D:/SteamLibrary/steamapps/common/Warhammer 40,000 DARKTIDE/mods/CustomCharacterBots/",
	"C:/Users/heartattackphil/Documents/darktide/CustomCharacterBots/",
	"mods/CustomCharacterBots/",
}

local function debug_timestamp()
	local ok, stamp = pcall(function()
		return os.date("%Y%m%d_%H%M%S")
	end)

	return ok and stamp or tostring(math.floor(safe_clock()))
end

local function ccb_debug_lines()
	local lines = {
		"Custom Character Bots runtime debug",
		"timestamp=" .. debug_timestamp(),
		"playerlike_loaded=" .. tostring(PlayerlikeBehavior ~= nil),
		"playerlike_load_error=" .. tostring(PlayerlikeBehaviorLoadError or "none recorded"),
		"betterbots_active=" .. tostring(betterbots_active()),
		"betterbots_compat_enabled=" .. tostring(betterbots_compat_enabled()),
		"tertium_active=" .. tostring(tertium_active()),
		"experimental_features_enabled=" .. tostring(experimental_features_enabled()),
		"behavior_learning_active=" .. tostring(behavior_learning_enabled()),
		"ccb_saved_weapon_hooks_active=" .. tostring(saved_weapon_compat_enabled()),
		"",
		"[runtime counters]",
	}

	if PlayerlikeBehavior and PlayerlikeBehavior.debug_lines then
		local counter_lines = PlayerlikeBehavior.debug_lines()

		for i = 1, #counter_lines do
			lines[#lines + 1] = counter_lines[i]
		end
	else
		lines[#lines + 1] = "player-like behavior diagnostics are not loaded"
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "[ccb-provided bots]"

	local bot_lines, bot_error = alive_ccb_bot_lines()

	if bot_error then
		lines[#lines + 1] = "unavailable=" .. tostring(bot_error)
	elseif #bot_lines == 0 then
		lines[#lines + 1] = "none"
	else
		for i = 1, #bot_lines do
			lines[#lines + 1] = bot_lines[i]
		end
	end

	return lines
end

local function save_ccb_debug_file()
	local filename = "ccb_debug_" .. debug_timestamp() .. ".txt"
	local text = table.concat(ccb_debug_lines(), "\n") .. "\n"
	local last_error = nil

	if not io or not io.open then
		return false, filename, "Lua file writing is unavailable in this runtime"
	end

	for i = 1, #CCB_DEBUG_OUTPUT_DIRS do
		local path = CCB_DEBUG_OUTPUT_DIRS[i] .. filename
		local file, open_error = io.open(path, "w")

		if file then
			local ok, write_error = pcall(function()
				file:write(text)
				file:close()
			end)

			if ok then
				return true, path, nil
			end

			last_error = tostring(write_error)
		else
			last_error = tostring(open_error)
		end
	end

	return false, filename, last_error or "unknown write error"
end

function alive_ccb_bot_lines()
	local lines = {}
	local player_manager = Managers and Managers.player
	local alive_lookup = rawget(_G, "ALIVE")

	if not (player_manager and player_manager.players) then
		return lines, "player manager unavailable"
	end

	local players = player_manager:players()

	if not players then
		return lines, nil
	end

	for _, player in pairs(players) do
		if player and not player:is_human_controlled() then
			local unit = player.player_unit

			if unit and (not alive_lookup or alive_lookup[unit]) then
				local profile = player.profile and player:profile()

				if profile and profile._ccb_resolved then
					local slot = type(player.slot) == "function" and player:slot() or "?"
					local name = type(player.name) == "function" and player:name() or profile._ccb_source_character_name or profile.name or "<bot>"
					local provider = profile._ccb_behavior_provider or profile._bb_external_profile or "unknown"
					local source_index = profile._ccb_source_profile_index or "?"
					local source_id = profile._ccb_source_character_id or profile_id(profile)

					lines[#lines + 1] = string.format(
						"slot=%s name=%s source_index=%s source_id=%s provider=%s loadout=%s",
						tostring(slot),
						tostring(name),
						tostring(source_index),
						tostring(source_id),
						tostring(provider),
						tostring(profile._ccb_combat_loadout_mode or profile._ccb_combat_profile or "saved")
					)
				end
			end
		end
	end

	return lines, nil
end

local function armor_types()
	local ok, ArmorSettings = pcall(require, "scripts/settings/damage/armor_settings")
	local types = ok and ArmorSettings and ArmorSettings.types

	return types and types.armored, types and types.super_armor
end

local function archetype_name(profile)
	local archetype = profile and profile.archetype

	if type(archetype) == "table" then
		return archetype.name or archetype.archetype_name or "<unknown>"
	end

	return archetype or "<unknown>"
end

local function profile_level(profile)
	return profile and (profile.current_level or profile.level) or "?"
end

local function profile_id(profile)
	return profile and (profile.character_id or profile.id) or "<missing-id>"
end

local function reset_bot_swap_state()
	bot_swap_count = 0
	last_swap_t = -math.huge
	table.clear(used_profile_ids)
end

local function describe_error(error)
	if type(error) ~= "table" then
		return tostring(error)
	end

	local direct_message = error.message or error.error or error.reason or error.details

	if direct_message then
		return tostring(direct_message)
	end

	local parts = {}
	local count = 0

	for key, value in pairs(error) do
		count = count + 1

		if count > 4 then
			parts[#parts + 1] = "..."
			break
		end

		if tostring(key) == "__locals" or tostring(key) == "traceback" then
			return "profile service was not ready yet"
		end

		parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
	end

	if #parts == 0 then
		return tostring(error)
	end

	local message = table.concat(parts, ", ")

	if string.find(message, "Promise Stack", 1, true) or string.find(message, "__locals", 1, true) then
		return "profile service was not ready yet"
	end

	if #message > 180 then
		return string.sub(message, 1, 177) .. "..."
	end

	return message
end

local function is_current_profile(profile, selected_profile)
	local selected_id = profile_id(selected_profile)

	return selected_id ~= "<missing-id>" and profile_id(profile) == selected_id
end

local function shallow_copy(source)
	if type(source) ~= "table" then
		return source
	end

	local copy = {}

	for key, value in pairs(source) do
		copy[key] = value
	end

	return copy
end

local function copy_profile(source_profile)
	if table.clone_instance then
		return table.clone_instance(source_profile)
	end

	return shallow_copy(source_profile)
end

local function copy_slot(profile, safe_profile, slot_name)
	if safe_profile.loadout and safe_profile.loadout[slot_name] then
		profile.loadout = profile.loadout or {}
		profile.loadout[slot_name] = safe_profile.loadout[slot_name]
	end

	if safe_profile.visual_loadout and safe_profile.visual_loadout[slot_name] then
		profile.visual_loadout = profile.visual_loadout or {}
		profile.visual_loadout[slot_name] = safe_profile.visual_loadout[slot_name]
	end

	if safe_profile.loadout_item_ids and safe_profile.loadout_item_ids[slot_name] then
		profile.loadout_item_ids = profile.loadout_item_ids or {}
		profile.loadout_item_ids[slot_name] = safe_profile.loadout_item_ids[slot_name]
	end

	if safe_profile.loadout_item_data and safe_profile.loadout_item_data[slot_name] then
		profile.loadout_item_data = profile.loadout_item_data or {}
		profile.loadout_item_data[slot_name] = safe_profile.loadout_item_data[slot_name]
	end
end

local function apply_bot_safe_combat(profile)
	local archetype = archetype_name(profile)
	local safe_profile_name = SAFE_BOT_PROFILE_BY_ARCHETYPE[archetype]

	if not safe_profile_name then
		mod:warning("No bot-safe combat profile is mapped for archetype %s.", tostring(archetype))
		return
	end

	local ok, ProfileUtils = pcall(require, "scripts/utilities/profile_utils")

	if not ok or not ProfileUtils or not ProfileUtils.get_bot_profile then
		mod:warning("Could not load ProfileUtils for bot-safe combat substitution.")
		return
	end

	local safe_ok, safe_profile = pcall(ProfileUtils.get_bot_profile, safe_profile_name)

	if not safe_ok or not safe_profile then
		mod:warning("Could not resolve bot-safe profile %s: %s", tostring(safe_profile_name), tostring(safe_profile))
		return
	end

	for i = 1, #COMBAT_SLOTS do
		copy_slot(profile, safe_profile, COMBAT_SLOTS[i])
	end

	if safe_profile.bot_gestalts then
		profile.bot_gestalts = safe_profile.bot_gestalts
	end

	profile.talents = {}
	profile.selected_nodes = {}
	profile._ccb_combat_profile = safe_profile_name
end

local function apply_default_bot_gestalts(profile)
	if profile.bot_gestalts == nil then
		profile.bot_gestalts = table.clone and table.clone(DEFAULT_BOT_GESTALTS) or shallow_copy(DEFAULT_BOT_GESTALTS)
	end
end

local function is_server()
	local state = Managers.state
	local game_session = state and state.game_session

	return game_session and game_session.is_server and game_session:is_server() == true
end

local function host_type()
	local multiplayer_session = Managers.multiplayer_session

	if multiplayer_session and multiplayer_session.host_type then
		local ok, result = pcall(multiplayer_session.host_type, multiplayer_session)

		if ok then
			return result
		end
	end

	local connection = Managers.connection

	if connection and connection.host_type then
		local ok, result = pcall(connection.host_type, connection)

		if ok then
			return result
		end
	end

	return "<unknown>"
end

local function substitution_allowed()
	if not mod:get("enable_one_bot_swap") then
		return false
	end

	if not is_server() then
		return false
	end

	if mod:get("solo_only") then
		local current_host_type = host_type()

		return current_host_type == "singleplay" or current_host_type == "singleplay_backend_session"
	end

	return true
end

function saved_weapon_compat_enabled()
	return mod:get("enable_one_bot_swap") == true
		and (mod:get("combat_loadout_mode") or "saved_loadout") == "saved_loadout"
		and not betterbots_compat_enabled()
end

local function bot_vo_support_enabled()
	return mod:get("enable_one_bot_swap") == true and mod:get("enable_bot_vo_support") ~= false
end

local function playerlike_behavior_enabled()
	return mod:get("enable_one_bot_swap") == true
		and experimental_features_enabled()
		and mod:get("enable_playerlike_behavior") ~= false
		and not betterbots_compat_enabled()
end

local function safe_identifier(profile)
	local id = tostring(profile_id(profile))

	return "ccb_" .. string.gsub(id, "[^%w_%-]", "_")
end

local function profile_is_eligible(profile)
	local id = profile_id(profile)
	local archetype = archetype_name(profile)
	local allowed_archetype = not mod:get("skip_experimental_archetypes") or CORE_ARCHETYPES[archetype]
	local duplicate_allowed = mod:get("allow_duplicate_profiles") == true

	return id ~= "<missing-id>"
		and id ~= selected_profile_id
		and allowed_archetype
		and (duplicate_allowed or not used_profile_ids[id])
end

local function build_eligible_profiles()
	local eligible = {}

	for i = 1, #profiles_cache do
		local profile = profiles_cache[i]

		if profile_is_eligible(profile) then
			eligible[#eligible + 1] = {
				index = i,
				profile = profile,
			}
		end
	end

	return eligible
end

local function select_profile_for_bot()
	local preferred_index = tonumber(mod:get("preferred_profile_index")) or 0

	if preferred_index > 0 then
		local preferred_profile = profiles_cache[preferred_index]

		if preferred_profile and profile_is_eligible(preferred_profile) then
			return preferred_profile, preferred_index
		end

		mod:warning("Preferred profile index %s was unavailable, current, duplicate, or filtered.", tostring(preferred_index))
	end

	local eligible = build_eligible_profiles()

	if #eligible == 0 then
		return nil
	end

	local choice = eligible[math.random(1, #eligible)]

	return choice.profile, choice.index
end

local function prepare_bot_profile(source_profile, source_index)
	local profile = copy_profile(source_profile)
	local provider = betterbots_compat_enabled() and "BetterBots" or "CustomCharacterBots"

	if (mod:get("combat_loadout_mode") or "bot_safe_weapons") == "bot_safe_weapons" then
		apply_bot_safe_combat(profile)
	else
		apply_default_bot_gestalts(profile)
	end

	profile.identifier = safe_identifier(profile)
	profile.is_local_profile = true
	profile._ccb_resolved = true
	profile._ccb_behavior_provider = provider
	profile._ccb_profile_source = "CustomCharacterBots"
	profile._ccb_source_character_id = profile_id(source_profile)
	profile._ccb_source_character_name = source_profile and source_profile.name
	profile._ccb_source_profile_index = source_index
	profile._ccb_combat_loadout_mode = mod:get("combat_loadout_mode") or "saved_loadout"
	profile._ccb_display_name = profile.name

	if provider == "BetterBots" then
		profile._bb_external_profile = "CustomCharacterBots"
	end

	return profile
end

local function profile_summary_line(index, profile, selected_profile)
	local marker = is_current_profile(profile, selected_profile) and " (current)" or ""
	return string.format(
		"#%d %s%s | class=%s | level=%s | id=%s",
		index,
		tostring(profile.name or "<unnamed>"),
		marker,
		archetype_name(profile),
		tostring(profile_level(profile)),
		tostring(profile_id(profile))
	)
end

local function log_profile(index, profile, selected_profile)
	local line = profile_summary_line(index, profile, selected_profile)

	mod:echo(line)

	if mod:get("detailed_logging") then
		mod:info(line)
	end
end

local function handle_profiles_result(result, options)
	options = options or {}
	fetch_in_progress = false
	profiles_ready = false

	local profiles = result and result.profiles or {}
	local selected_profile = result and result.selected_profile
	selected_profile_id = profile_id(selected_profile)

	table.clear(profiles_cache)

	for i = 1, #profiles do
		profiles_cache[i] = profiles[i]
	end

	if options.quiet then
		if mod:get("detailed_logging") then
			mod:echo("Custom Character Bots: cached %d saved character(s).", #profiles_cache)
			mod:info("Custom Character Bots: cached %d saved character(s).", #profiles_cache)
		end
	else
		mod:echo("Custom Character Bots: found %d saved character(s).", #profiles_cache)
	end

	if not options.quiet then
		for i = 1, #profiles_cache do
			log_profile(i, profiles_cache[i], selected_profile)
		end
	elseif mod:get("detailed_logging") then
		for i = 1, #profiles_cache do
			mod:info(profile_summary_line(i, profiles_cache[i], selected_profile))
		end
	end

	profiles_ready = #profiles_cache > 0
	auto_fetch_last_success_t = safe_clock()
	reset_bot_swap_state()

	return result
end

local function handle_profiles_error(error, options)
	options = options or {}
	fetch_in_progress = false
	local had_profiles = profiles_ready and #profiles_cache > 0
	local message = describe_error(error)

	if not had_profiles then
		profiles_ready = false
	end

	if options.quiet then
		auto_fetch_next_t = safe_clock() + AUTO_FETCH_BACKEND_RETRY_DELAY

		if mod:get("detailed_logging") then
			mod:info("Custom Character Bots: auto-cache skipped, will retry (%s).", message)
		end

		return
	end

	mod:warning("Failed to fetch saved character profiles: %s", message)

	if had_profiles then
		mod:echo("Custom Character Bots: could not refresh saved character profiles. Existing cache kept.")
	else
		mod:echo("Custom Character Bots: could not fetch saved character profiles. Check the game log for details.")
	end
end

function mod.fetch_profiles(options)
	options = options or {}

	if fetch_in_progress then
		if not options.quiet then
			mod:echo("Custom Character Bots: profile fetch is already in progress.")
		end

		return
	end

	local data_service = Managers.data_service
	local profiles_service = data_service and data_service.profiles

	if not profiles_service or not profiles_service.fetch_all_profiles then
		if not options.quiet then
			mod:echo("Custom Character Bots: profile service is not available in this game state.")
		end

		return
	end

	fetch_in_progress = true

	if not options.quiet then
		mod:echo("Custom Character Bots: fetching saved character profiles...")
	elseif mod:get("detailed_logging") then
		mod:info("Custom Character Bots: auto-fetching saved character profiles...")
	end

	local ok, promise = pcall(profiles_service.fetch_all_profiles, profiles_service)

	if not ok or not promise then
		fetch_in_progress = false
		mod:warning("Profile fetch call failed: %s", tostring(promise))

		if not options.quiet then
			mod:echo("Custom Character Bots: profile fetch call failed.")
		end

		return
	end

	if promise.next then
		promise:next(function(result)
			return handle_profiles_result(result, options)
		end):catch(function(error)
			return handle_profiles_error(error, options)
		end)
	else
		fetch_in_progress = false
		mod:warning("Profile service returned a non-promise result: %s", tostring(promise))

		if not options.quiet then
			mod:echo("Custom Character Bots: profile service returned an unexpected result.")
		end
	end
end

local function current_game_mode_name()
	local game_mode = Managers.state and Managers.state.game_mode

	if game_mode and game_mode.game_mode_name then
		local ok, result = pcall(game_mode.game_mode_name, game_mode)

		if ok then
			return result
		end
	end

	return nil
end

local function in_mourningstar()
	local game_mode_name = current_game_mode_name()

	return game_mode_name == "hub" or game_mode_name == "prologue_hub"
end

local function active_gameplay_session()
	local state = Managers.state

	return state and state.game_session ~= nil
end

local function auto_cache_source(game_mode_name)
	if in_mourningstar() then
		return "hub_auto_cache"
	end

	if game_mode_name then
		return "frontend_auto_cache"
	end

	return "profile_service_auto_cache"
end

local function profile_service_ready()
	local profiles_service = Managers.data_service and Managers.data_service.profiles

	return profiles_service and profiles_service.fetch_all_profiles ~= nil
end

local function maybe_reset_bot_swap_state_for_game_mode()
	local game_mode_name = current_game_mode_name() or "<frontend>"

	if game_mode_name == auto_reset_last_game_mode then
		return
	end

	auto_reset_last_game_mode = game_mode_name
	reset_bot_swap_state()

	if mod:get("detailed_logging") then
		mod:info("Custom Character Bots: reset bot substitution state for game mode %s.", tostring(game_mode_name))
	end
end

local function maybe_auto_fetch_profiles(t)
	if mod:get("auto_fetch_on_load") ~= true then
		return
	end

	if fetch_in_progress or t < auto_fetch_next_t then
		return
	end

	local game_mode_name = current_game_mode_name()

	if game_mode_name ~= auto_fetch_last_game_mode then
		auto_fetch_last_game_mode = game_mode_name
		auto_fetch_next_t = t + 1
		auto_fetch_frontend_ready_t = nil

	end

	if active_gameplay_session() and not in_mourningstar() then
		return
	end

	if game_mode_name == nil and not profiles_ready then
		auto_fetch_frontend_ready_t = auto_fetch_frontend_ready_t or (t + AUTO_FETCH_FRONTEND_STARTUP_DELAY)

		if t < auto_fetch_frontend_ready_t then
			return
		end
	end

	if profiles_ready and t - auto_fetch_last_success_t < AUTO_FETCH_REFRESH_DELAY then
		return
	end

	if not profile_service_ready() then
		auto_fetch_next_t = t + AUTO_FETCH_RETRY_DELAY

		return
	end

	auto_fetch_next_t = t + AUTO_FETCH_RETRY_DELAY
	mod.fetch_profiles({
		quiet = true,
		source = auto_cache_source(game_mode_name),
	})
end

local function substitute_profile(original_profile)
	if not substitution_allowed() then
		return original_profile
	end

	local max_swaps = tonumber(mod:get("max_bots_to_swap")) or 1

	if bot_swap_count >= max_swaps then
		local bot_lines = alive_ccb_bot_lines and alive_ccb_bot_lines() or {}

		if #bot_lines == 0 then
			reset_bot_swap_state()
		else
			return original_profile
		end
	end

	if bot_swap_count >= max_swaps then
		return original_profile
	end

	if not profiles_ready or #profiles_cache == 0 then
		mod:warning("Bot substitution skipped: no cached profiles. Run /ccb_profiles before starting a test mission.")
		return original_profile
	end

	local source_profile, source_index = select_profile_for_bot()

	if not source_profile then
		mod:warning("Bot substitution skipped: no non-current saved character profile was available.")
		return original_profile
	end

	local ok, prepared_profile = pcall(prepare_bot_profile, source_profile, source_index)

	if not ok or not prepared_profile then
		mod:warning("Bot substitution failed while preparing profile: %s", tostring(prepared_profile))
		return original_profile
	end

	bot_swap_count = bot_swap_count + 1
	last_swap_t = os.clock()
	used_profile_ids[profile_id(source_profile)] = true

	mod:echo(
		"Custom Character Bots: replacing bot #%d with #%s %s (%s).",
		bot_swap_count,
		tostring(source_index or "?"),
		tostring(prepared_profile.name or "<unnamed>"),
		archetype_name(prepared_profile)
	)

	if mod:get("detailed_logging") then
		mod:info(
			"Substituted bot profile: source_id=%s source_index=%s identifier=%s host_type=%s behavior_provider=%s combat_profile=%s",
			tostring(profile_id(source_profile)),
			tostring(source_index or "?"),
			tostring(prepared_profile.identifier),
			tostring(host_type()),
			tostring(prepared_profile._ccb_behavior_provider or "unknown"),
			tostring(prepared_profile._ccb_combat_profile or "saved")
		)
	end

	return prepared_profile
end

local function call_bot_add_with_external_profile_yield(func, self, local_player_id, profile)
	if not (profile and profile._ccb_resolved) then
		return func(self, local_player_id, profile)
	end

	local tertium = tertium_mod()

	if not (tertium and type(tertium.get) == "function") then
		return func(self, local_player_id, profile)
	end

	local old_get = tertium.get

	tertium.get = function(mod_self, setting_id, ...)
		if type(setting_id) == "string" and string.match(setting_id, "^character_%d+$") then
			return "none"
		end

		return old_get(mod_self, setting_id, ...)
	end

	local ok, result = pcall(func, self, local_player_id, profile)
	tertium.get = old_get

	if ok then
		return result
	end

	error(result, 0)
end

function mod.reset_bot_swap_test()
	reset_bot_swap_state()
	mod:echo("Custom Character Bots: one-bot swap test counter reset.")
end

local function register_bot_hooks()
	if bot_hooks_registered then
		return
	end

	bot_hooks_registered = true

	mod:hook("BotSynchronizerHost", "add_bot", function(func, self, local_player_id, profile)
		local ok, replacement = pcall(substitute_profile, profile)

		if ok and replacement then
			return call_bot_add_with_external_profile_yield(func, self, local_player_id, replacement)
		end

		mod:warning("Bot substitution hook failed, falling back to vanilla bot: %s", tostring(replacement))
		return func(self, local_player_id, profile)
	end)

	mod:hook("BotPlayer", "set_profile", function(func, self, profile)
		if self._profile and self._profile._ccb_resolved and not self._ccb_blocked_profile_overwrite and os.clock() - last_swap_t < 5 then
			self._ccb_blocked_profile_overwrite = true
			mod:warning("Blocked a short-window profile overwrite to preserve Custom Character Bots test profile.")
			return
		end

		return func(self, profile)
	end)

	mod:hook_require("scripts/utilities/profile_utils", function(ProfileUtils)
		mod:hook(ProfileUtils, "generate_random_name", function(func, profile)
			if profile and profile._ccb_display_name then
				return profile._ccb_display_name
			end

			return func(profile)
		end)
	end)

	if BotVoSupport then
		BotVoSupport.init({
			mod = mod,
			fixed_time = fixed_time,
			is_enabled = bot_vo_support_enabled,
		})

		hook_require_now("scripts/extension_systems/behavior/bot_behavior_extension", function(BotBehaviorExtension)
			if not BotBehaviorExtension or rawget(BotBehaviorExtension, "__ccb_bot_vo_support_patch") then
				return
			end

			BotBehaviorExtension.__ccb_bot_vo_support_patch = true

			if PlayerlikeBehavior then
				return
			end

			mod:hook_safe(BotBehaviorExtension, "update", function(_self, unit)
				BotVoSupport.update_bot(unit, BLACKBOARDS and BLACKBOARDS[unit])
			end)
		end)

		hook_require_now("scripts/extension_systems/interaction/interactions/revive_interaction", function(ReviveInteraction)
			if not ReviveInteraction or rawget(ReviveInteraction, "__ccb_bot_vo_thanks_patch") then
				return
			end

			ReviveInteraction.__ccb_bot_vo_thanks_patch = true

			mod:hook_safe(
				ReviveInteraction,
				"stop",
				function(_self, _world, interactor_unit, unit_data_component, _t, result, interactor_is_server)
					if interactor_is_server and result == "success" and unit_data_component then
						BotVoSupport.on_revived(interactor_unit, unit_data_component.target_unit)
					end
				end
			)
		end)

		hook_require_now("scripts/utilities/player_assist_notifications", function(PlayerAssistNotifications)
			if not PlayerAssistNotifications or rawget(PlayerAssistNotifications, "__ccb_bot_vo_stimm_thanks_patch") then
				return
			end

			PlayerAssistNotifications.__ccb_bot_vo_stimm_thanks_patch = true

			mod:hook_safe(PlayerAssistNotifications, "show_notification", function(target_unit, assisted_by_unit, notification_type)
				if notification_type == "stimmed" or notification_type == "cleansed" then
					BotVoSupport.on_stimmed(assisted_by_unit, target_unit, notification_type)
				end
			end)
		end)
	end

	if PlayerlikeBehavior then
		PlayerlikeBehavior.init({
			mod = mod,
			fixed_time = fixed_time,
			is_enabled = playerlike_behavior_enabled,
			behavior_learning = BehaviorLearning,
		})

		hook_require_now("scripts/settings/breed/breeds/chaos/chaos_poxwalker_bomber_breed", function(breed_data)
			if breed_data and breed_data.not_bot_target then
				breed_data.not_bot_target = nil
			end
		end)

		hook_require_now("scripts/extension_systems/behavior/bot_behavior_extension", function(BotBehaviorExtension)
			if not BotBehaviorExtension then
				return
			end

			BotBehaviorExtension.__ccb_playerlike_behavior_dispatch = PlayerlikeBehavior

			if not rawget(BotBehaviorExtension, "__ccb_playerlike_behavior_dispatch_patch") then
				BotBehaviorExtension.__ccb_playerlike_behavior_dispatch_patch = true

				mod:hook_safe(BotBehaviorExtension, "update", function(self, unit, dt, t)
					local behavior = rawget(BotBehaviorExtension, "__ccb_playerlike_behavior_dispatch")

					if behavior and behavior.update_behavior then
						behavior.update_behavior(self, unit, BLACKBOARDS and BLACKBOARDS[unit], dt, t)
					end

					if BotVoSupport then
						BotVoSupport.update_bot(unit, BLACKBOARDS and BLACKBOARDS[unit])
					end
				end)
			end

			if not rawget(BotBehaviorExtension, "__ccb_playerlike_movement_target_dispatch_patch") then
				BotBehaviorExtension.__ccb_playerlike_movement_target_dispatch_patch = true

				mod:hook_safe(BotBehaviorExtension, "_update_movement_target", function(self, unit, dt, t)
					local behavior = rawget(BotBehaviorExtension, "__ccb_playerlike_behavior_dispatch")

					if behavior and behavior.update_movement_target then
						behavior.update_movement_target(self, unit, dt, t)
					end
				end)
			end

			if not BotBehaviorExtension or rawget(BotBehaviorExtension, "__ccb_playerlike_behavior_patch") then
				return
			end

			BotBehaviorExtension.__ccb_playerlike_behavior_patch = true
			PlayerlikeBehavior.install_bot_behavior_destination_hooks(BotBehaviorExtension)
		end)

		hook_require_now("scripts/extension_systems/perception/bot_perception_extension", function(BotPerceptionExtension)
			if not BotPerceptionExtension or rawget(BotPerceptionExtension, "__ccb_playerlike_perception_patch") then
				return
			end

			BotPerceptionExtension.__ccb_playerlike_perception_patch = true

			mod:hook_safe(BotPerceptionExtension, "update", function(_self, unit, dt, t)
				PlayerlikeBehavior.update_perception(unit, BLACKBOARDS and BLACKBOARDS[unit], dt, t)
			end)
		end)

		hook_require_now("scripts/extension_systems/input/bot_unit_input", function(BotUnitInput)
			if not BotUnitInput then
				return
			end

			BotUnitInput.__ccb_playerlike_behavior_dispatch = PlayerlikeBehavior
			
			if PlayerlikeBehavior.install_bot_unit_input_get_hook then
				PlayerlikeBehavior.install_bot_unit_input_get_hook(BotUnitInput)
			end

			PlayerlikeBehavior.install_bot_unit_input_hooks(BotUnitInput)
		end)

		hook_require_now("scripts/extension_systems/group/bot_group", function(BotGroup)
			PlayerlikeBehavior.install_bot_group_hooks(BotGroup)
		end)

		hook_require_now("scripts/extension_systems/behavior/nodes/actions/bot/bt_bot_melee_action", function(BtBotMeleeAction)
			if not BtBotMeleeAction or rawget(BtBotMeleeAction, "__ccb_playerlike_engage_patch") then
				return
			end

			BtBotMeleeAction.__ccb_playerlike_engage_patch = true
			PlayerlikeBehavior.install_bot_melee_action_hooks(BtBotMeleeAction)
		end)
	end

	hook_require_now("scripts/extension_systems/behavior/utilities/conditions/bt_bot_conditions", function(conditions)
		if not conditions or rawget(conditions, "__ccb_reload_condition_patch") then
			return
		end

		conditions.__ccb_reload_condition_patch = true

		if conditions.should_reload then
			local original_should_reload = conditions.should_reload

			conditions.should_reload = function(unit, blackboard, scratchpad, condition_args, action_data, is_running)
				if saved_weapon_compat_enabled() and is_running then
					return true
				end

				if saved_weapon_compat_enabled() then
					local ok, Ammo = pcall(require, "scripts/utilities/ammo")

					if ok and Ammo then
						local ok_clip, clip_percentage = pcall(Ammo.current_slot_clip_percentage, unit, "slot_secondary")
						local ok_reserve, reserve_percentage = pcall(Ammo.current_slot_percentage, unit, "slot_secondary")

						if ok_clip and ok_reserve and clip_percentage <= 0 and reserve_percentage > 0 then
							return true
						end
					end
				end

				return original_should_reload(unit, blackboard, scratchpad, condition_args, action_data, is_running)
			end
		end

		if conditions.should_vent_overheat then
			local original_should_vent_overheat = conditions.should_vent_overheat

			conditions.should_vent_overheat = function(unit, blackboard, scratchpad, condition_args, action_data, is_running)
				if saved_weapon_compat_enabled() and is_running then
					local ok, Overheat = pcall(require, "scripts/utilities/overheat")
					local overheat_limit_type = condition_args and condition_args.overheat_limit_type
					local stop_percentage = condition_args and condition_args.stop_percentage

					if ok and Overheat and overheat_limit_type and stop_percentage then
						return Overheat.slot_percentage(unit, "slot_secondary", overheat_limit_type) >= stop_percentage
					end
				end

				return original_should_vent_overheat(unit, blackboard, scratchpad, condition_args, action_data, is_running)
			end
		end
	end)

	if WeaponActionShoot then
		hook_require_now("scripts/extension_systems/behavior/nodes/actions/bot/bt_bot_shoot_action", function(BtBotShootAction)
			if not BtBotShootAction or rawget(BtBotShootAction, "__ccb_shoot_action_patch") then
				return
			end

			BtBotShootAction.__ccb_shoot_action_patch = true

			local ok_loadout, PlayerUnitVisualLoadout = pcall(
				require,
				"scripts/extension_systems/visual_loadout/utilities/player_unit_visual_loadout"
			)

			if not ok_loadout or not PlayerUnitVisualLoadout then
				mod:warning("Custom Character Bots: could not load visual loadout utility for shoot compatibility.")
				return
			end

			mod:hook_safe(BtBotShootAction, "enter", function(_self, unit, _breed, _blackboard, scratchpad)
				if not saved_weapon_compat_enabled() or not scratchpad then
					return
				end

				local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
				local visual_loadout_extension = ScriptUnit.has_extension(unit, "visual_loadout_system")

				if not unit_data_extension or not visual_loadout_extension then
					return
				end

				local inventory_component = unit_data_extension:read_component("inventory")
				local weapon_template = PlayerUnitVisualLoadout.wielded_weapon_template(visual_loadout_extension, inventory_component)
				scratchpad._ccb_weapon_template = weapon_template

				if WeaponActionShoot.normalize(weapon_template, scratchpad) and mod:get("detailed_logging") then
					mod:info(
						"Custom Character Bots: normalized shoot inputs fire=%s aim_fire=%s aim=%s unaim=%s",
						tostring(scratchpad.fire_action_input),
						tostring(scratchpad.aim_fire_action_input),
						tostring(scratchpad.aim_action_input),
						tostring(scratchpad.unaim_action_input)
					)
				end

				if
					weapon_template
					and weapon_template.name == "ogryn_gauntlet_p1_m1"
					and scratchpad.action_input_extension
					and scratchpad.aim_action_input
				then
					scratchpad.aiming_shot = true
					scratchpad.aim_done_t = 0
					scratchpad.action_input_extension:bot_queue_action_input("weapon_action", scratchpad.aim_action_input)
				end
			end)

			mod:hook(BtBotShootAction, "_start_aiming", function(func, self, t, scratchpad)
				if saved_weapon_compat_enabled() and scratchpad and not scratchpad.aim_action_input then
					scratchpad.aiming_shot = false
					scratchpad.aim_done_t = 0
					return
				end

				return func(self, t, scratchpad)
			end)

			mod:hook(BtBotShootAction, "_stop_aiming", function(func, self, scratchpad)
				if saved_weapon_compat_enabled() and scratchpad and not scratchpad.unaim_action_input then
					scratchpad.aiming_shot = false
					scratchpad.aim_done_t = 0
					return
				end

				return func(self, scratchpad)
			end)

			mod:hook(BtBotShootAction, "_fire", function(func, self, scratchpad, action_data, bot_unit_input, t)
				if saved_weapon_compat_enabled() and scratchpad then
					local weapon_template = scratchpad._ccb_weapon_template

					if weapon_template and weapon_template.name == "ogryn_gauntlet_p1_m1" then
						scratchpad.aiming_shot = true
					end

					if scratchpad.aiming_shot and not scratchpad.aim_fire_action_input then
						scratchpad.aiming_shot = false
					end

					if not scratchpad.fire_action_input then
						return
					end
				end

				return func(self, scratchpad, action_data, bot_unit_input, t)
			end)
		end)
	end

	if SustainedFire then
		SustainedFire.init({
			mod = mod,
			fixed_time = fixed_time,
			is_enabled = saved_weapon_compat_enabled,
		})

		hook_require_now("scripts/extension_systems/input/bot_unit_input", function(BotUnitInput)
			if not BotUnitInput or rawget(BotUnitInput, "__ccb_sustained_fire_input_patch") then
				return
			end

			BotUnitInput.__ccb_sustained_fire_input_patch = true
			SustainedFire.install_bot_unit_input_hooks(BotUnitInput)
		end)
	end

	if WeaponSpecialAction then
		local armored, super_armor = armor_types()

		WeaponSpecialAction.init({
			mod = mod,
			is_enabled = saved_weapon_compat_enabled,
			ARMOR_TYPE_ARMORED = armored,
			ARMOR_TYPE_SUPER_ARMOR = super_armor,
		})
	end

	if SustainedFire or WeaponSpecialAction or BehaviorLearning then
		if BehaviorLearning then
			hook_require_now("scripts/utilities/action/action_handler", function(ActionHandler)
				if not ActionHandler or rawget(ActionHandler, "__ccb_behavior_learning_patch") then
					return
				end

				ActionHandler.__ccb_behavior_learning_patch = true

				mod:hook_safe(
					ActionHandler,
					"start_action",
					function(self, id, _action_objects, action_name, _action_params, action_settings, used_input, t)
						if behavior_learning_enabled() then
							BehaviorLearning.observe_started_action(
								self and self._unit,
								id,
								action_name,
								action_settings,
								used_input,
								t
							)
						end
					end
				)
			end)
		end

		hook_require_now("scripts/extension_systems/action_input/player_unit_action_input_extension", function(PlayerUnitActionInputExtension)
			if not PlayerUnitActionInputExtension or rawget(PlayerUnitActionInputExtension, "__ccb_action_input_patch") then
				return
			end

			PlayerUnitActionInputExtension.__ccb_action_input_patch = true

			mod:hook_safe(PlayerUnitActionInputExtension, "extensions_ready", function(self, _world, unit)
				self._ccb_player_unit = unit
			end)

			mod:hook(PlayerUnitActionInputExtension, "bot_queue_action_input", function(func, self, id, action_input, raw_input)
				local original_action_input = action_input

				if WeaponSpecialAction and saved_weapon_compat_enabled() and id == "weapon_action" then
					action_input, raw_input =
						WeaponSpecialAction.rewrite_weapon_action_input(self._ccb_player_unit, action_input, raw_input)
				end

				local result = func(self, id, action_input, raw_input)

				if result ~= nil and WeaponSpecialAction and saved_weapon_compat_enabled() and id == "weapon_action" then
					WeaponSpecialAction.observe_queued_weapon_action(
						self._ccb_player_unit,
						action_input,
						original_action_input
					)
				end

				if result ~= nil and SustainedFire and saved_weapon_compat_enabled() and id == "weapon_action" then
					SustainedFire.observe_queued_weapon_action(self._ccb_player_unit, action_input)
				end

				if result ~= nil and BehaviorLearning and behavior_learning_enabled() then
					BehaviorLearning.observe_action_input(self._ccb_player_unit, id, action_input, raw_input)
				end

				return result
			end)
		end)
	end

	hook_require_now("scripts/ui/constant_elements/elements/subtitles/constant_element_subtitles", function(ConstantElementSubtitles)
		if not ConstantElementSubtitles or rawget(ConstantElementSubtitles, "__ccb_subtitle_name_patch") then
			return
		end

		ConstantElementSubtitles.__ccb_subtitle_name_patch = true

		mod:hook(ConstantElementSubtitles, "_add_subtitle", function(func, self, currently_playing, secondary_subtitle)
			local currently_playing_unit = currently_playing and currently_playing.currently_playing_unit

			if currently_playing_unit then
				local state_manager = Managers.state
				local player_unit_spawn_manager = state_manager and state_manager.player_unit_spawn
				local is_player_unit = player_unit_spawn_manager
					and player_unit_spawn_manager:is_player_unit(currently_playing_unit)
				local player = is_player_unit and player_unit_spawn_manager:owner(currently_playing_unit)
				local profile = player and player.profile and player:profile()

				if profile and profile._ccb_resolved then
					currently_playing._ccb_original_speaker_name = currently_playing._ccb_original_speaker_name
						or currently_playing.speaker_name
					currently_playing.speaker_name = nil
					local old_is_human_controlled = player.is_human_controlled

					player.is_human_controlled = function()
						return true
					end

					local ok, result = pcall(func, self, currently_playing, secondary_subtitle)

					player.is_human_controlled = old_is_human_controlled
					currently_playing.speaker_name = currently_playing._ccb_original_speaker_name

					if ok then
						return result
					end

					error(result)
				end
			end

			return func(self, currently_playing, secondary_subtitle)
		end)
	end)
end

function mod.on_all_mods_loaded()
	if BehaviorLearning then
		BehaviorLearning.init({
			mod = mod,
			fixed_time = fixed_time,
			profile_id = profile_id,
			is_enabled = behavior_learning_enabled,
		})
	end

	mod:command("ccb_profiles", "List saved character profiles visible to Custom Character Bots.", function()
		mod.fetch_profiles()
	end)

	mod:command("ccb_reset", "Reset the Custom Character Bots one-bot swap test counter.", function()
		mod.reset_bot_swap_test()
	end)

	mod:command("ccb_status", "Show Custom Character Bots integration status.", function()
		mod:echo("Custom Character Bots: enabled=%s", tostring(mod:get("enable_one_bot_swap") == true))
		mod:echo("Custom Character Bots: BetterBots active=%s", tostring(betterbots_active()))
		mod:echo("Custom Character Bots: Tertium active=%s", tostring(tertium_active()))
		mod:echo("Custom Character Bots: BetterBots behavior mode=%s", tostring(betterbots_compat_enabled()))
		mod:echo("Custom Character Bots: experimental features=%s", tostring(experimental_features_enabled()))
		mod:echo("Custom Character Bots: behavior learning active=%s", tostring(behavior_learning_enabled()))
		mod:echo("Custom Character Bots: CCB saved-weapon hooks active=%s", tostring(saved_weapon_compat_enabled()))
		mod:echo("Custom Character Bots: CCB player-like behavior active=%s", tostring(playerlike_behavior_enabled()))
		mod:echo("Custom Character Bots: use /ccb_bots and BetterBots /bb_state in mission to confirm live bot handoff.")
	end)

	mod:command("ccb_bots", "Show alive Custom Character Bots currently carrying CCB profile metadata.", function()
		local lines, error = alive_ccb_bot_lines()

		if error then
			mod:echo("Custom Character Bots: /ccb_bots unavailable (%s)", tostring(error))

			return
		end

		if #lines == 0 then
			mod:echo("Custom Character Bots: no alive CCB-provided bots found.")

			return
		end

		mod:echo("Custom Character Bots: alive CCB-provided bots:")

		for i = 1, #lines do
			mod:echo("  %s", lines[i])
		end
	end)

	mod:command("ccb_learn_status", "Show learned Custom Character Bots behavior profiles.", function()
		if not BehaviorLearning then
			mod:echo("Custom Character Bots: behavior learning is not loaded.")

			return
		end

		if not behavior_learning_enabled() then
			mod:echo("Custom Character Bots: behavior learning is installed but inactive. Enable Experimental features and Experimental behavior learning to record new data.")
		end

		local lines = BehaviorLearning.status_lines()

		if #lines == 0 then
			mod:echo("Custom Character Bots: no learned behavior profiles yet.")

			return
		end

		mod:echo("Custom Character Bots: learned behavior profiles:")

		for i = 1, #lines do
			mod:echo("  %s", lines[i])
		end
	end)

	mod:command("ccb_learn_reset", "Clear learned Custom Character Bots behavior profiles.", function()
		if BehaviorLearning then
			BehaviorLearning.reset()
		end

		mod:echo("Custom Character Bots: learned behavior profiles cleared.")
	end)

	local save_debug_command = function()
		local ok, path_or_name, error = save_ccb_debug_file()

		if ok then
			mod:echo("Custom Character Bots: debug saved to %s", tostring(path_or_name))

			return
		end

		mod:echo("Custom Character Bots: could not save debug file %s: %s", tostring(path_or_name), tostring(error))
	end

	mod:command("ccb_debug", "Save Custom Character Bots runtime behavior counters to a text file.", save_debug_command)
	mod:command("ccb_debug_file", "Save Custom Character Bots runtime behavior counters to a text file.", save_debug_command)
	mod:command("ccb_dump", "Save Custom Character Bots runtime behavior counters to a text file.", save_debug_command)

	mod:command("ccb_debug_chat", "Show Custom Character Bots runtime behavior counters in chat.", function()
		local lines = ccb_debug_lines()

		mod:echo("Custom Character Bots: runtime debug counters:")

		for i = 1, #lines do
			mod:echo("  %s", lines[i])
		end
	end)

	mod:command("ccb_debug_reset", "Reset Custom Character Bots runtime behavior counters.", function()
		if PlayerlikeBehavior and PlayerlikeBehavior.reset_debug then
			PlayerlikeBehavior.reset_debug()
		end

		mod:echo("Custom Character Bots: runtime debug counters reset.")
	end)

	register_bot_hooks()
	register_weapon_template_hooks()
end

function mod.update()
	maybe_reset_bot_swap_state_for_game_mode()
	maybe_auto_fetch_profiles(safe_clock())

	if BehaviorLearning and behavior_learning_enabled() then
		BehaviorLearning.update()
	end
end

function mod.on_unload()
	if BehaviorLearning then
		BehaviorLearning.on_unload()
	end

	mod:remove_all_commands()
end
