---@class mod : DL_Mod
local mod = get_mod("hud_studio")

mod.bootstrap.script_phase()

---@param status string      "enter" or "exit"
---@param state_name string  the game state being entered/exited
function mod.on_game_state_changed(status, state_name)
	if status ~= "exit" then
		return
	end

	local CompositeMaterial = rawget(mod, "hud_studio_composite_material")
	if CompositeMaterial then
		CompositeMaterial.release_all()
	end

	local Appearance = rawget(mod, "hud_studio_player_appearance")
	if Appearance and Appearance.release_all then
		Appearance.release_all()
	end

	local MaterialDeps = rawget(mod, "hud_studio_material_deps")
	if MaterialDeps and MaterialDeps.revalidate then
		MaterialDeps.revalidate()
	end
end

function mod.on_all_mods_loaded()
	local Session = rawget(mod, "hud_studio_session")
	if Session then
		local changed = Session.refresh_requires()
		if changed > 0 then
			mod:info("on_all_mods_loaded: %d block(s) changed requires state", changed)
		end
	end

	local BlockLibrary = rawget(mod, "hud_studio_block_library")
	if BlockLibrary then
		BlockLibrary.refresh()
	end
end
