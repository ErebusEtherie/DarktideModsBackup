---@class mod : DL_Mod
local mod = get_mod("hud_studio")

---@class DL_ModSettings
local DEFAULTS = {

}

mod.dl.data.set_defaults(DEFAULTS)

local d = mod.dl.data

mod.settings_widgets = {
	d.group("editor_group", {

		d.keybind("editor_toggle"):call("toggle_editor"),
		d.checkbox("editor_duplicate_in_place"),
	}),
	d.group("news_group", {

		d.keybind("news_toggle"):call("toggle_news"),
		d.checkbox("news_on_update", true),
	}),
}

if mod:get("debug") then
	mod.settings_widgets[#mod.settings_widgets + 1] = d.group("debug", {

		d.keybind("reset_read_news"):call("reset_read_news"),
	})
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	hot_reload = { "localization", "script" },

	allow_rehooking = true,
	options = {
		widgets = mod.settings_widgets,
	},
}
