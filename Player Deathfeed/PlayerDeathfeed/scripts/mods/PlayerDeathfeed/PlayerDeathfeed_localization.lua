
local InputUtils = require("scripts/managers/input/input_utils")

local localizations = {
	mod_name = {
		en = "Player Deathfeed",
	},
	mod_description = {
		en = "Shows player downs and deaths in killfeed and/or popup notifications.",
	},
	killfeed = {
		en = "Killfeed Options:",
	},
	show_killfeed = {
		en = "Report in Killfeed",
	},
	report_down_feed = {
		en = "Report: Knockdowns",
	},
	report_death_feed = {
		en = "Report: Deaths",
	},
	show_type_feed = {
		en = "Show: Attack Information",
	},
	show_damage_feed = {
		en = "Show: Damage Amount",
	},
	notification = {
		en = "Notification Options:",
	},
	show_notification = {
		en = "Report in Notifications",
	},
	report_down_notification = {
		en = "Report: Knockdowns",
	},
	dead_color = {
		en = "Background Color: Death",
	},
	knock_color = {
		en = "Background Color: Knock Down",
	},
	report_death_notification = {
		en = "Report: Deaths",
	},
	show_type_note = {
		en = "Show Attack Information",
	},
	show_damage_note = {
		en = "Show Damage Amount",
	},
	show_disabled_note = {
		en = "Show Disabled State",
	},
	note_time = {
		en = "Notification Display Duration (sec)",
	},
	detailed_notification = {
		en = "Detailed Report",
	},
	detailed_description = {
		en = "On: Shows all damage taken during the reporting period.\nOff: Shows only the killing blow.",
	},
	damage_window = {
		en = "Detailed Report Recording Period (sec)",
	},
	echo = {
		en = "Echo",
	},
	echo_feed = {
		en = "Echo Killfeed in Private Chat",
	},
	echo_note = {
		en = "Echo Notification in Private Chat",
	},
}

local function readable(text)
    local readable_string = ""
    local tokens = string.split(text, "_")
    for i, token in ipairs(tokens) do
        local first_letter = string.sub(token, 1, 1)
        token = string.format("%s%s", string.upper(first_letter), string.sub(token, 2))
        readable_string = string.trim(string.format("%s %s", readable_string, token))
    end

    return readable_string
end

local color_names = Color.list
for i, color_name in ipairs(color_names) do
	local color_values = Color[color_name](100, true)
	local text = InputUtils.apply_color_to_input_text(readable(color_name), color_values)
	localizations[color_name] = {
		en = text
	}
end

return localizations