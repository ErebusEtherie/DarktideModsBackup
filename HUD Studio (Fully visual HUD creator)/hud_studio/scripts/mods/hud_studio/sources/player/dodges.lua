---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_dodges then
	return mod.hud_studio_player_dodges
end

local Player = mod.dl.player
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

---@return number|nil
local function gameplay_time()
	local Managers = _G.Managers
	local time_manager = Managers and Managers.time or nil
	if not time_manager then
		return nil
	end
	local ok, t = pcall(time_manager.time, time_manager, "gameplay")
	return ok and t or nil
end

---@param unit_data table
---@param weapon_extension table
---@param buff_extension table
---@param t number
local function read_efficient_dodges(unit_data, weapon_extension, buff_extension, t)
	local dodge_state = unit_data:read_component("dodge_character_state")
	local movement_state = unit_data:read_component("movement_state")
	local slide_state = unit_data:read_component("slide_character_state")
	if not dodge_state or not movement_state or not slide_state then
		return 0, 0, 0, 0, false
	end

	local weapon_dodge_template = weapon_extension:dodge_template()
	local stat_buffs = buff_extension:stat_buffs()

	local extra_consecutive_dodges = math.round(stat_buffs.extra_consecutive_dodges or 0)
	local dr_start = (weapon_dodge_template and weapon_dodge_template.diminishing_return_start or 2)
		+ extra_consecutive_dodges
	local dr_limit = dr_start + (weapon_dodge_template and weapon_dodge_template.diminishing_return_limit or 1)

	local consecutive_dodges = math.min(dodge_state.consecutive_dodges, dr_limit + dr_start)
	local is_sliding = movement_state.method == "sliding"
	local was_in_dodge_before_slide = slide_state.was_in_dodge_cooldown
	local is_dodging = movement_state.is_dodging == true
	local is_cooled_down = dodge_state.consecutive_dodges_cooldown < t

	local is_actually_dodging = movement_state.method ~= "vaulting" and is_dodging

	if is_cooled_down and not is_actually_dodging then
		consecutive_dodges = 0
	end
	if is_cooled_down and not was_in_dodge_before_slide and is_sliding then
		consecutive_dodges = 0
	end

	local archetype = unit_data:archetype()
	local base_dodge_template = archetype and archetype.dodge
	local weapon_consecutive_dodges_reset = weapon_dodge_template and weapon_dodge_template.consecutive_dodges_reset
		or 0
	local buff_modifier = stat_buffs.dodge_cooldown_reset_modifier
	local reset_modifier = buff_modifier and 1 - (buff_modifier - 1) or 1
	local span = (
		(base_dodge_template and base_dodge_template.consecutive_dodges_reset or 0) + weapon_consecutive_dodges_reset
	) * reset_modifier
	local remaining = math.max(dodge_state.consecutive_dodges_cooldown - t, 0)

	local held = is_actually_dodging or (is_sliding and was_in_dodge_before_slide) or (span > 0 and remaining >= span)

	return dr_start, consecutive_dodges, remaining, span, held
end

---@param unit Unit
---@return number|nil efficient_max, number|nil consecutive_used, number refresh_seconds, number refresh_span, boolean refresh_held
local function efficient_dodges(unit)
	local unit_data = Player.extensions(unit, "unit_data_system")
	local weapon_extension = Player.extensions(unit, "weapon_system")
	local buff_extension = Player.extensions(unit, "buff_system")
	if not unit_data or not weapon_extension or not buff_extension then
		return 0, 0, 0, 0, false
	end

	local t = gameplay_time()
	if not t then
		return 0, 0, 0, 0, false
	end

	local ok, efficient_max, consecutive_used, refresh_seconds, refresh_span, refresh_held =
		pcall(read_efficient_dodges, unit_data, weapon_extension, buff_extension, t)

	if not ok or efficient_max == nil then
		return 0, 0, 0, 0, false
	end
	return efficient_max, consecutive_used, refresh_seconds or 0, refresh_span or 0, refresh_held == true
end

---@type PlayerField
local Field = {
	fields = {
		status = {
			dodges = DataTypes.field("integer", "[-n..n] efficient dodges remaining; negative past the cap"),
			dodges_clamped = DataTypes.field("integer", "[0..n] efficient dodges remaining; clamped to 0"),
			dodges_max = DataTypes.field("integer", "[0..n] maximum number of efficient dodges"),
			dodge_refresh_percent = DataTypes.field(
				"number",
				"[0..100] % progress of the consecutive-dodge reset timer; 0 while still dodging, "
					.. "100 once dodges have refreshed"
			),
			dodge_refresh_seconds = DataTypes.field(
				"number",
				"[0..n] [seconds] seconds left until consecutive dodges reset; 0 while still dodging "
					.. "and once refreshed"
			),
		},
	},
}

---@param values table                    per-slot output table, rewritten in place
---@param player DL_PlayerObject | nil     slot occupant, or nil when the slot is empty
---@param unit Unit | nil                  the player's live unit, or nil when dead/absent
function Field.write(values, player, unit)
	local status = values.status or {}
	values.status = status

	if not unit then
		status.dodges, status.dodges_clamped, status.dodges_max = 0, 0, 0
		status.dodge_refresh_percent, status.dodge_refresh_seconds = 100, 0
		return
	end

	local efficient_max, consecutive_used, refresh_seconds, refresh_span, refresh_held = efficient_dodges(unit)
	if not efficient_max then
		status.dodges, status.dodges_clamped, status.dodges_max = 0, 0, 0
		status.dodge_refresh_percent, status.dodge_refresh_seconds = 100, 0
		return
	end

	if refresh_held then
		status.dodge_refresh_percent, status.dodge_refresh_seconds = 0, 0
	elseif refresh_span > 0 and refresh_seconds > 0 then
		status.dodge_refresh_percent = math.clamp((1 - refresh_seconds / refresh_span) * 100, 0, 100)
		status.dodge_refresh_seconds = refresh_seconds
	else
		status.dodge_refresh_percent, status.dodge_refresh_seconds = 100, 0
	end

	local dodges_max = math.ceil(efficient_max)
	status.dodges = dodges_max - (consecutive_used or 0)
	status.dodges_max = dodges_max
	status.dodges_clamped = math.clamp(status.dodges, 0, dodges_max)
end

mod.hud_studio_player_dodges = Field
return Field
