local mod = get_mod("SortModMenu")
local dmf = get_mod("DMF")

local rebuilder = mod:io_dofile("SortModMenu/scripts/mods/SortModMenu/options_rebuilder")

mod.on_all_mods_loaded = function(status, state_name)
  if rebuilder and rebuilder.rebuild_silent_now then
        rebuilder.rebuild_silent_now()
    end
end



dmf.initialize_dmf_options_view = function()
  -- CUSTOM VERSION OF mod_option.lua's initialize_dmf_options_view --

  -- Alphabetize the 'Toggle Mods' widget DMF adds too. 
  -- The dmf.options_widgets_data is from the dmf.create_mod_options_settings function
  local sort_order = mod:get("sort_order")
  if sort_order == "Ascending" then
    table.sort(dmf.options_widgets_data, function(a, b)
      local nameA = mod.process_mod_name(a[1].readable_mod_name)
      local nameB = mod.process_mod_name(b[1].readable_mod_name)

      return nameA < nameB
    end)
  elseif sort_order == "Descending" then -- Descending
    table.sort(dmf.options_widgets_data, function(a, b)
      local nameA = mod.process_mod_name(a[1].readable_mod_name)
      local nameB = mod.process_mod_name(b[1].readable_mod_name)

      return nameA > nameB
    end)
  else -- Default to Ascending (in the possibility of a bug)
    table.sort(dmf.options_widgets_data, function(a, b)
      local nameA = mod.process_mod_name(a[1].readable_mod_name)
      local nameB = mod.process_mod_name(b[1].readable_mod_name)

      return nameA < nameB
    end)
  end

  -- Original Code -- dmf:add_require_path("dmf/scripts/mods/dmf/modules/ui/options/dmf_options_view")
  dmf:add_require_path("SortModMenu/scripts/mods/SortModMenu/custom_dmf_options_view") -- Modification
  dmf:add_require_path("dmf/scripts/mods/dmf/modules/ui/options/dmf_options_view_definitions")
  dmf:add_require_path("dmf/scripts/mods/dmf/modules/ui/options/dmf_options_view_settings")
  dmf:add_require_path("dmf/scripts/mods/dmf/modules/ui/options/dmf_options_view_content_blueprints")

  dmf:register_view({
    view_name = "dmf_options_view",
    view_settings = {
      init_view_function = function (ingame_ui_context)
        return true
      end,
      class = "DMFOptionsView",
      disable_game_world = false,
      display_name = "loc_options_view_display_name",
      game_world_blur = 1.1,
      load_always = true,
      load_in_hub = true,
      package = "packages/ui/views/options_view/options_view",
      -- Original Code -- path = "dmf/scripts/mods/dmf/modules/ui/options/dmf_options_view",
      path = "SortModMenu/scripts/mods/SortModMenu/custom_dmf_options_view", -- Modification
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
  
  -- Original Code -- dmf:io_dofile("dmf/scripts/mods/dmf/modules/ui/options/dmf_options_view")
  dmf:io_dofile("SortModMenu/scripts/mods/SortModMenu/custom_dmf_options_view") -- Modification
end
