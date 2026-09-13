---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_profile then
	return mod.hud_studio_player_profile
end

local Player = mod.dl.player
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local SynRead = mod:core(mod.hud_studio_player_syn_read, "sources/player/reads/state_your_name_read")
local TlRead = mod:core(mod.hud_studio_player_tl_read, "sources/player/reads/true_level_read")
local ProgressionCache = mod:core(mod.hud_studio_progression_cache, "sources/player/cache/progression_cache")

---@type PlayerField
local Field = {
	fields = {
		profile = {
			name = DataTypes.field("string", "[string|nil] character name of player in this slot"),
			syn_display_name = DataTypes.field(
				"string",
				"[string|nil] character name with State Your Name's formatting; falls back to the plain name when that mod is switched off or has not captured this player yet, and to a notice when it is not installed at all"
			),
			tl_display_name = DataTypes.field(
				"string",
				"[string|nil] character name with True Level's level suffix, formatted per the user's True Level settings; falls back to the plain name when that mod is switched off or has not cached this character yet, and to a notice when it is not installed at all"
			),

			level = DataTypes.field("integer", "[0..30|nil] character level, clamped at the level cap"),
			total_level = DataTypes.field("integer", "[0..n|nil] character level including levels earned past the cap"),
			extra_levels = DataTypes.field("integer", "[0..n|nil] levels earned past the level cap"),
			prestige = DataTypes.field("integer", "[0..n|nil] number of times total XP covers the entire level track"),
			havoc_rank = DataTypes.field("integer", "[0..n|nil] highest Havoc rank reached in the current cadence"),
		},
	},
	sections = {
		{ id = "name", label = "Character Name" },
		{ id = "levels", label = "Levels" },
		{ id = "mods", label = "Mods" },
	},
	field_meta = {
		["profile.name"] = { section = "name" },
		["profile.syn_display_name"] = { section = "mods" },
		["profile.tl_display_name"] = { section = "mods" },
		["profile.level"] = { section = "levels" },
		["profile.extra_levels"] = { section = "levels" },
		["profile.total_level"] = { section = "levels" },
		["profile.prestige"] = { section = "levels" },
		["profile.havoc_rank"] = { section = "levels" },
	},
	write = function(values, player, unit, time_now)
		local profile = values.profile or {}
		values.profile = profile
		local player_name = player and Player.name(player) or nil
		profile.name = player_name

		local player_profile = player and Player.profile(player)
		local character_id = player_profile and player_profile.character_id
		local account_id = player and Player.account_id(player)
		local level = player_profile and player_profile.current_level or nil

		if
			not (player_profile and character_id)
			or not player_name
			or not (player.is_human_controlled and player:is_human_controlled())
		then
			profile.syn_display_name = player_name
			profile.tl_display_name = player_name
			profile.level = level
			profile.total_level = level
			profile.extra_levels = nil
			profile.prestige = nil
			profile.havoc_rank = nil
		else
			profile.syn_display_name = SynRead.read(player, character_id, player_name, time_now)
			profile.tl_display_name = TlRead.read(character_id, player_name, time_now)
		end

		local progression = ProgressionCache.record(character_id, account_id, level)

		profile.level = progression and progression.level or level
		profile.total_level = progression and progression.total_level or level
		profile.extra_levels = progression and progression.extra_levels or 0
		profile.prestige = progression and progression.prestige or 0
		profile.havoc_rank = progression and progression.havoc_rank or 0

		profile.true_level = progression and progression.total_level or level
	end,
}

mod.hud_studio_player_profile = Field
return Field
