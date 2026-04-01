local mod = get_mod("Mourningstar_dialogue_improved")
mod.version = "1.2.06"
mod:info("Mourningstar Dialogue Improved is installed, using version: " .. tostring(mod.version))

local colours = {
	title = "200,140,20",
	subtitle = "226,199,126",
	text = "169,191,153",
}

return {
	mod_name = {
		en = "{#color("
			.. colours.title
			.. ")} "
			.. "{#color(0,207,255)}M{#color(9,206,245)}o{#color(18,205,236)}u{#color(28,204,226)}r{#color(37,203,217)}n{#color(47,202,207)}i{#color(56,201,198)}n{#color(66,200,188)}g{#color(75,199,179)}s{#color(85,198,170)}t{#color(94,197,160)}a{#color(103,196,151)}r {#color(113,195,141)}D{#color(122,194,132)}i{#color(132,193,122)}a{#color(141,192,113)}l{#color(151,191,103)}o{#color(160,190,94)}g{#color(170,189,85)}u{#color(179,188,75)}e {#color(188,187,66)}I{#color(198,186,56)}m{#color(207,185,47)}p{#color(217,184,37)}r{#color(226,183,28)}o{#color(236,182,18)}v{#color(245,181,9)}e{#color(255,180,0)}d{#reset()}",
	},
	mod_description = {
		en = "{#color("
			.. colours.text
			.. ")}"
			.. "Listen to radio chatter within menus, completely disable chatter throughout and more, to improve the dialogue within the Mourningstar Hub"
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Author: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Version: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
	},
	disable_mourningstar_chatter = {
		en = "Toggle Mourningstar chatter?",
	},
	disable_radio_chatter = {
		en = "Disable mission radio chatter?",
	},
	disable_all_chatter = {
		en = "Disable all chatter?",
	},
	general_settings = {
		en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
	},
	disable_mourningstar_chatter_tooltip = {
		en = "Toggles radio/npc chatter whilst within the Mourningstar hub.",
	},
	disable_radio_chatter_tooltip = {
		en = "Toggles in-mission radio chatter, but keeps player character interactions.",
	},
	disable_all_chatter_tooltip = {
		en = "Toggles ALL npc chatter, including radios, player character interactions, npc conversations... all of it. (May cause some issues in solo play)",
	},
}
