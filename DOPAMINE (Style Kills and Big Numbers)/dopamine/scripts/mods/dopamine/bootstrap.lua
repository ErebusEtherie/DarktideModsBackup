---@type mod
local mod = get_mod("dopamine")

local Bootstrap = {}

local function load(path)
	mod:io_dofile("dopamine/scripts/mods/dopamine/" .. path)
end

mod:io_dofile("dopamine/scripts/mods/dopamine/darklib/darklib")(mod, "dopamine/scripts/mods/dopamine/darklib")

load("hud/constants")

mod:io_dofile("dopamine/scripts/mods/dopamine/lib/lib_loader")(mod)

function Bootstrap.script_phase()
	load("utils/settings_schema")

	load("utils/runtime")

	load("utils/event/manager")

	load("hooks/update_loop")

	load("hooks/movement_handler")

	load("hooks/perfect_block")

	load("hooks/kill_handler")

	load("hooks/objective_markers")

	load("hooks/objective_time")

	load("hooks/teammate_rescue")

	load("utils/task/manager")

	load("utils/stats/manager")

	load("utils/boss_tracker")

	load("hooks/enemy_spawn") 
	load("hooks/coherency") 
	load("hooks/stim_tracker") 
	load("hooks/finesse")

	load("utils/mission_summary/history_store")
	load("utils/mission_summary/stats")
	load("utils/mission_summary/manager")

	load("hooks/hud_registration")

	load("hooks/mission_summary")

	load("utils/mission_summary/debug")

	load("hooks/slot_swap")

	load("hooks/margin_editor_input")

	load("hooks/combat_feed")

	load("hooks/chat_offset")

	load("hooks/mission_speaker")
end

mod.bootstrap = Bootstrap

return Bootstrap
