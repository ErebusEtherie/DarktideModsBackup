local mod = get_mod("SortModMenu")
local dmf = get_mod("DMF")

local MOD_NAME = "SortModMenu"
local VIEW_FILE = "SortModMenu/scripts/mods/SortModMenu/custom_dmf_options_view"

-- ####################################################################################################################
-- ##### View registration ############################################################################################
-- ####################################################################################################################

local function register_sorted_options_view()
	dmf:add_require_path(VIEW_FILE)
	dmf:register_view({
		view_name = "dmf_options_view",
		view_settings = {
			init_view_function = function ()
				return true
			end,
			class = "DMFOptionsView",
			disable_game_world = false,
			display_name = "loc_options_view_display_name",
			game_world_blur = 1.1,
			load_always = true,
			load_in_hub = true,
			package = "packages/ui/views/options_view/options_view",
			path = VIEW_FILE,
			state_bound = true,
			enter_sound_events = {
				"wwise/events/ui/play_ui_enter_short"
			},
			exit_sound_events = {
				"wwise/events/ui/play_ui_back_short"
			},
			wwise_states = {
				options = "ingame_menu"
			}
		},
		view_transitions = {},
		view_options = {
			close_all = false,
			close_previous = false,
			close_transition_time = nil,
			transition_time = nil
		}
	})
end

-- Runs after DMF's own registration, so ours takes precedence.
local original_initialize_dmf_options_view = dmf.initialize_dmf_options_view
dmf.initialize_dmf_options_view = function (...)
	if original_initialize_dmf_options_view then
		original_initialize_dmf_options_view(...)
	end

	register_sorted_options_view()
end

-- ####################################################################################################################
-- ##### Options refresh ##############################################################################################
-- ####################################################################################################################

mod.on_all_mods_loaded = function ()
	local option_blocks = dmf.options_widgets_data
	local index

	for i = 1, #option_blocks do
		local header = option_blocks[i][1]

		if header and header.mod_name == MOD_NAME then
			index = i
			break
		end
	end

	if not index then
		return
	end

	table.remove(option_blocks, index)

	dmf.initialize_mod_options(mod, {
		localize = true,
		widgets = mod.build_option_widgets(),
	})

	local rebuilt_block = table.remove(option_blocks)
	table.insert(option_blocks, index, rebuilt_block)
end
