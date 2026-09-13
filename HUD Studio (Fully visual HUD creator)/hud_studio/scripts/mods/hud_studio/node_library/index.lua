
local mod = get_mod("hud_studio")

local lines, important = mod.dl.loc_helpers.lines, mod.dl.loc_helpers.important

local BLOCKS = "scripts/mods/hud_studio/node_library/blocks/"

local t = {
	personal = "personal",
	team = "team",
	player_panel = "player_panel",
	fancy = "fancy",
	vitals = "vitals",
	dodges = "dodges",
	ability = "ability",
	sample = "sample",
	tools = "tools",
}

return {
	version = 1,
	label = "HUD Studio",
	author = "hud_studio",
	blocks = {
		{
			file = BLOCKS .. "fancy_player_panel_1",
			label = "Fancy Player Panel 1",
			summary = lines(
				important("Move the buffs row in Blocks Panel > Darktide Canvas"),
				"",
				important("Intended to be placed in the bottom center of the screen"),
				"",
				"An extensively styled player panel with dynamic colors and pocketable icons.",
				"",
				"A good example of what you can do by stacking materials and applying conditional colors."
			),
			tags = { t.personal, t.player_panel, t.fancy },
		},
		{
			file = BLOCKS .. "compact_player_panel",
			label = "Compact Player Panel",
			summary = lines(
				important("Intended for teammates, not personal "),
				"",
				"A compact player panel with an added ability charge bar and icon display.",
				"",
				"Remember you can scale the entire block to be slightly larger."
			),
			tags = { t.team, t.player_panel, t.vitals },
		},
		{
			file = BLOCKS .. "dodge_and_status_bars",
			label = "Dodge and Status Bars",
			summary = lines(
				"Compact stamina, toughness and health bars with % displays, with a dodge counter on the left.",
				"",
				"Remember you can scale the entire block to be slightly larger."
			),
			tags = { t.personal, t.vitals, t.dodges },
		},
		{
			file = BLOCKS .. "dodge_counters",
			label = "Dodge Counter (Sample)",
			summary = lines(
				"Various configurations of dodge counters: vertical, horizontal, curved, text, with dynamic colors based on remaining dodges.",
				"",
				"Remember you can scale the entire block to be slightly larger."
			),
			tags = { t.personal, t.dodges, t.sample },
		},
		{
			file = BLOCKS .. "Portrait_Frame_and_Insignia",
			label = "Portrait, Frame & Insignia",
			summary = lines(
				"Preset portrait frame & insignia for the bound player.",
				"",
				"Remember you can scale the entire block to be slightly larger."
			),
			tags = { t.personal, t.team, t.sample },
		},
		{
			file = BLOCKS .. "Ability_Container",
			label = "Ability Container",
			summary = lines(
				"A dynamic ability container - faithful to the vanilla element.",
				"",
				"Remember you can scale the entire block to be slightly larger."
			),
			tags = { t.personal, t.team, t.sample },
		},
		{
			file = BLOCKS .. "Grid_Guide_Block",
			label = "Grid Guide",
			summary = lines("A see-through rectangle with a grid on its block. Might be useful for aligning elements."),
			tags = { t.tools },
		},
		{
			file = BLOCKS .. "True_Level_Name",
			label = "True Level Name",
			summary = lines(
				important("Requires True Level mod!"),
				"",
				"The display name of a player, as is configured in your True Level settings."
			),

			requires = { "true_level" },
			tags = { t.personal, t.team },
		},
	},
}
