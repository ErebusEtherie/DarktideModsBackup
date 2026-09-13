local mod = get_mod("MortisBuffManager")

local Catalog = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_catalog")

-- Stable builds do not expose or execute temporary input diagnostics.
mod._settings = { mortis_debug_input = false }
if mod:get("mortis_debug_input") == true then mod:set("mortis_debug_input", false) end

local function checkbox(setting_id, default_value)
	return {
		setting_id = setting_id,
		type = "checkbox",
		default_value = default_value == true,
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
				setting_id = "mortis_settings_group",
				type = "group",
				sub_widgets = {
					checkbox("enable_custom_mortis_buffs", false),
                    { setting_id = "mortis_mode", type = "dropdown", default_value = "preselect", title = "mortis_mode", tooltip = "mortis_mode_desc",
                        options = { { text = "mortis_mode_preselect", value = "preselect" }, { text = "mortis_mode_draft", value = "draft" }, { text = "mortis_mode_competition", value = "competition" } } },
                    { setting_id = "mortis_competition_hud_style", type = "dropdown", default_value = "bar_percent", title = "mortis_competition_hud_style", tooltip = "mortis_competition_hud_style_desc",
                        options = { { text = "mortis_competition_hud_bar", value = "bar" }, { text = "mortis_competition_hud_bar_percent", value = "bar_percent" },
                            { text = "mortis_competition_hud_percent", value = "percent" }, { text = "mortis_competition_hud_hidden", value = "hidden" } } },
					{
						setting_id = "mortis_buff_limit",
						type = "numeric",
						default_value = 10,
						range = { 0, Catalog.max_selection },
						decimals_number = 0,
						title = "mortis_buff_limit",
						tooltip = "mortis_buff_limit_desc",
					},
				},
			},
		},
	},
}

local competition = { setting_id = "mortis_competition_group", type = "group", sub_widgets = {} }
for _, pair in ipairs({ { "horde", 0.25 }, { "special", 5 }, { "elite", 2.5 }, { "boss", 40 }, { "weakened_boss", 20 }, { "captain", 50 } }) do
    local key = "mortis_kill_" .. pair[1]
    competition.sub_widgets[#competition.sub_widgets + 1] = { setting_id = key, type = "numeric", default_value = pair[2],
        range = { 0, 100 }, decimals_number = 2, title = key, tooltip = "mortis_kill_weight_desc" }
end
data.options.widgets[#data.options.widgets + 1] = competition
table.insert(data.options.widgets, { setting_id = "open_workspace_bind", type = "keybind",
    default_value = {}, keybind_trigger = "pressed", keybind_type = "function_call",
    function_name = "open_workspace", title = "open_workspace_bind", tooltip = "open_workspace_bind_desc" })
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
