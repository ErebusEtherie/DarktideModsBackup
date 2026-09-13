---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_stimms then
	return mod.hud_studio_player_stimms
end

local Ability = mod:core(mod.hud_studio_player_ability_read, "sources/player/reads/ability_read")
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local Pocketable = mod:core(mod.hud_studio_player_pocketable_read, "sources/player/reads/pocketable_read")
local Player = mod.dl.player

local STIM_SLOT = "slot_pocketable_small"

local HIVE_SCUM_ABILITY_ID = "pocketable_ability"

local HIVE_SCUM_ICON = "content/ui/materials/icons/pocketables/hud/syringe_broker"

local SYRINGE_KEYWORD = "syringe"

local scratch = {}

---@param unit Unit | nil
---@return number, number
local function read_active_stim(unit)
	local buff_extension = unit and Player.extensions(unit, "buff_system") or nil
	local buffs = buff_extension and buff_extension.buffs and buff_extension:buffs()

	if not buffs then
		return 0, 0
	end

	local seconds_remaining, percent_remaining = 0, 0

	for i = 1, #buffs do
		local buff = buffs[i]
		local template = buff:template()
		local keywords = template and template.keywords

		if keywords and table.array_contains(keywords, SYRINGE_KEYWORD) then
			local progress = buff:duration_progress() or 0
			local duration = buff:duration() or 0
			local remaining = duration * progress

			if remaining > seconds_remaining then
				seconds_remaining, percent_remaining = remaining, progress * 100
			end
		end
	end

	return seconds_remaining, percent_remaining
end

---@type PlayerField
local Field = {
	fields = {
		stimms = {

			icon = DataTypes.field("material", "[string|nil] path of material to held stimm icon"),
			icon_small = DataTypes.field("material", "[string|nil] path of material to held stimm icon (small)"),

			held = DataTypes.field("boolean", "[true/false] whether a stim is currently carried"),
			stimm_is_equipped = DataTypes.field(
				"boolean",
				"[true/false] whether the carried stim is currently in hand"
			),
			active = DataTypes.field("boolean", "[true/false] whether an injected stim is currently active"),
			active_seconds_remaining = DataTypes.field("number", "[0..n] [seconds] stim duration remaining"),
			active_percent_remaining = DataTypes.field(
				"number",
				"[0..100] % stim duration remaining; 100 = full duration"
			),

			hive_scum_charges = DataTypes.field(
				"integer",
				"[0..n] number of Hive Scum syringe charges currently available"
			),
			hive_scum_max_charges = DataTypes.field("integer", "[0..n] maximum number of Hive Scum syringe charges"),
			hive_scum_progress_percent_to_next_charge = DataTypes.field(
				"number",
				"[0..100] % progress to next Hive Scum syringe charge being ready"
			),
			hive_scum_cooldown_seconds_to_next_charge = DataTypes.field(
				"number",
				"[0..n] [seconds] seconds left until next Hive Scum syringe charge is ready"
			),
			held_color = DataTypes.field("rgba", "[{a,r,g,b}|nil] the color tint for the current stimm"),
		},
	},
	sections = {
		{ id = "icon", label = "Icon" },
		{ id = "status", label = "Status" },
		{ id = "hive_scum", label = "Hive Scum" },
	},
	field_meta = {
		["stimms.icon"] = { section = "icon" },
		["stimms.icon_small"] = { section = "icon" },
		["stimms.held"] = { section = "status" },
		["stimms.stimm_is_equipped"] = { section = "status" },
		["stimms.active"] = { section = "status" },
		["stimms.active_seconds_remaining"] = { section = "status" },
		["stimms.active_percent_remaining"] = { section = "status" },
		["stimms.hive_scum_charges"] = { section = "hive_scum" },
		["stimms.hive_scum_max_charges"] = { section = "hive_scum" },
		["stimms.hive_scum_progress_percent_to_next_charge"] = { section = "hive_scum" },
		["stimms.hive_scum_cooldown_seconds_to_next_charge"] = { section = "hive_scum" },
		["stimms.held_color"] = { section = "hive_scum" },
	},
	write = function(values, player, unit, time_now)
		local stimms = values.stimms or {}
		values.stimms = stimms

		stimms.id, stimms.icon, stimms.icon_small, stimms.held_color = Pocketable.read(unit, STIM_SLOT)
		stimms.held = stimms.id ~= nil

		local unit_data = Player.extensions(unit, "unit_data_system")
		local inventory = unit_data and unit_data:read_component("inventory")
		stimms.stimm_is_equipped = stimms.held and (inventory and inventory.wielded_slot) == STIM_SLOT

		stimms.active_seconds_remaining, stimms.active_percent_remaining = read_active_stim(unit)
		stimms.active = stimms.active_seconds_remaining > 0

		local ability = Ability.read(unit, HIVE_SCUM_ABILITY_ID, scratch, player)
		local is_hive_scum = ability.id ~= nil

		stimms.hive_scum_charges = ability.charges
		stimms.hive_scum_max_charges = ability.max_charges
		stimms.hive_scum_progress_percent_to_next_charge = is_hive_scum and ability.progress_percent_to_next_charge or 0
		stimms.hive_scum_cooldown_seconds_to_next_charge = is_hive_scum and ability.cooldown_seconds_to_next_charge or 0

		if is_hive_scum and not stimms.icon then
			stimms.icon = HIVE_SCUM_ICON
		end
	end,
}

mod.hud_studio_player_stimms = Field

return Field
