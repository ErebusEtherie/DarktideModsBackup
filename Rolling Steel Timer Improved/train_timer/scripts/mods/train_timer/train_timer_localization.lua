local mod = get_mod("train_timer")
mod.version = "1.3.03"
mod:info("Rolling Steel Timer Improved (Train Timer) is installed, using version: " .. tostring(mod.version))

local colours = {
	title = "200,140,20",
	subtitle = "226,199,126",
	text = "169,191,153",
}

mod.localisation = {
	mod_name = {
		en = "{#color("
			.. colours.title
			.. ")} "
			.. "{#color(255,140,0)}R{#color(255,144,0)}o{#color(255,149,0)}l{#color(255,154,0)}l{#color(255,159,0)}i{#color(255,163,0)}n{#color(255,168,0)}g {#color(255,173,0)}S{#color(255,178,0)}t{#color(255,183,0)}e{#color(255,187,0)}e{#color(255,192,0)}l {#color(255,197,0)}T{#color(255,202,0)}i{#color(255,207,0)}m{#color(255,211,0)}e{#color(255,216,0)}r {#color(255,221,0)}I{#color(255,226,0)}m{#color(255,231,0)}p{#color(255,235,0)}r{#color(255,240,0)}o{#color(255,245,0)}v{#color(255,250,0)}e{#color(255,255,0)}d{#reset()}",
		ru = "Таймер поезда",
	},
	mod_description = {
		en = "{#color("
			.. colours.text
			.. ")}"
			.. "Adds a numerical timer to the 'Rolling Steel' *train* operation mission alongside the normal progress bar."
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
		ru = "Train timer - Добавляет числовой таймер на миссии *поезда* «Стальной экспресс» наряду с обычной шкалой прогресса.",
	},
	mod_name_pizazz = {
		en = "{#color("
			.. colours.title
			.. ")} "
			.. "{#color(255,140,0)}R{#color(255,144,0)}o{#color(255,149,0)}l{#color(255,154,0)}l{#color(255,159,0)}i{#color(255,163,0)}n{#color(255,168,0)}g {#color(255,173,0)}S{#color(255,178,0)}t{#color(255,183,0)}e{#color(255,187,0)}e{#color(255,192,0)}l {#color(255,197,0)}T{#color(255,202,0)}i{#color(255,207,0)}m{#color(255,211,0)}e{#color(255,216,0)}r {#color(255,221,0)}I{#color(255,226,0)}m{#color(255,231,0)}p{#color(255,235,0)}r{#color(255,240,0)}o{#color(255,245,0)}v{#color(255,250,0)}e{#color(255,255,0)}d{#reset()}",
		ru = "Таймер поезда",
	},
	mod_name_boring = {
		en = "Rolling Steel Timer Improved",
	},
	mod_name_pizazz_toggle = {
		en = "Enable Name Pizazz",
	},
	mod_name_pizazz_tooltip = {
		en = "Toggles the rainbow colours effect on the mod name text. Requires a reload.\nIf enabled, you will get a small euphoric experience everytime you scroll through the mod menu, \nIf disabled - you will be a John Darktide and have no rainbow sprinkles (but I'll love you anyway).",
	},
	general_settings = {
		en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
	},
	placeholder = {
		en = "",
	},
	placeholder_tooltip = {
		en = "A placeholder entry to initialise the mod menu, does not do anything yet.\nMore features may be added at some point.",
	},
}

mod.toggle_pizazz = function()
	for key, values in pairs(mod.localisation) do
		if key == "mod_name" then
			for language, text in pairs(values) do
				if mod:get("mod_name_pizazz_toggle") then
					mod.localisation[key][language] = mod.localisation["mod_name_pizazz"][language]
				else
					mod.localisation[key][language] = mod.localisation["mod_name_boring"][language]
				end
			end
		end
	end
end

mod.toggle_pizazz()

return mod.localisation
