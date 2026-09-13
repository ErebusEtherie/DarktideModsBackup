

---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local VIEW_PATH = "hud_studio/scripts/mods/hud_studio/hud/news/HudNews"

mod:add_require_path(VIEW_PATH)

mod:register_view({
	view_name = "hud_studio_news_view",
	view_settings = {
		init_view_function = function(ingame_ui_context)
			return true
		end,
		state_bound = true,
		path = VIEW_PATH,
		class = "HudStudioNewsView",
		disable_game_world = false,
		load_always = true,
		load_in_hub = true,
		game_world_blur = 1.1,
		enter_sound_events = {
			UISoundEvents.system_menu_enter,
		},
		exit_sound_events = {
			UISoundEvents.system_menu_exit,
		},
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
	},
})

---@class HudStudioNewsRegistration
local Registration = {}

mod.hud_studio_news_registration = Registration

return Registration
