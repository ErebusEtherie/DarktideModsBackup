local mod = get_mod("realms_loadout")
local build = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/build_config")

mod._settings = mod._settings or {}

local function checkbox(setting_id, default_value)
	return {
		setting_id = setting_id,
		type = "checkbox",
		default_value = default_value == true,
		title = setting_id,
		tooltip = setting_id .. "_desc",
	}
end

local function talent_points_slider(setting_id, minimum)
	return {
		setting_id = setting_id,
		type = "numeric",
		default_value = 30,
		range = { minimum or 30, 99 },
		decimals_number = 0,
		title = setting_id,
		tooltip = setting_id .. "_desc",
	}
end

local data = {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "custom_talent_settings_group",
				type = "group",
				sub_widgets = {
					checkbox("enable_custom_talent_points", true),
					checkbox("enable_local_custom_talents", true),
					talent_points_slider("local_talent_points", 0),
					checkbox("unlock_all_auras", false),
					checkbox("unlock_all_keystones", false),
					checkbox("enable_bot_custom_talents", false),
					talent_points_slider("bot_talent_points"),
					checkbox("bot_talent_autofill", true),
                    { setting_id = "stimm_points", type = "numeric", default_value = 30, range = { 0, 103 },
                      decimals_number = 0, title = "stimm_points", tooltip = "stimm_points_desc" },
				},
			},
		},
	},
}

if build.talent_debug then
	table.insert(data.options.widgets[1].sub_widgets, checkbox("debug_talent_effects", false))
else
	mod._settings.debug_talent_effects = false
end

local function read_settings(widgets)
	for _, widget in ipairs(widgets) do
		if widget.type == "group" then
			read_settings(widget.sub_widgets or {})
		elseif widget.setting_id and widget.type ~= "button" then
			mod._settings[widget.setting_id] = mod:get(widget.setting_id)
		end
	end
end

read_settings(data.options.widgets)

return data
