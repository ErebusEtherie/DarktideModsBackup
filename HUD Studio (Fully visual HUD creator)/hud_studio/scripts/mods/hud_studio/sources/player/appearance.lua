---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_appearance then
	return mod.hud_studio_player_appearance
end

local Player = mod.dl.player
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

local CompositeMaterial = mod:core(mod.hud_studio_composite_material, "blocks/composite_material")

local FRAME_BASE_MATERIAL = "content/ui/materials/base/ui_portrait_frame_base"

local FRAME_EMPTY_BASE_MATERIAL = "content/ui/materials/base/ui_portrait_frame_base_no_render"

local PORTRAIT_BASE_MATERIAL = "content/ui/materials/base/ui_portrait_base"
local INSIGNIA_BASE_MATERIAL = "content/ui/materials/nameplates/insignias/default"
local INSIGNIA_TEXTURE_SLOT = "texture_map"
local FRAME_TEXTURE_SLOT = "portrait_frame_texture"

local STATE_SETTLE_SECONDS = 3

local DEMAND_TIMEOUT = 5

local function now()
	return os.clock()
end

---@type PlayerField
local Field = {
	fields = {
		profile = {
			insignia = DataTypes.field(
				"material",
				"[string|table|nil] the player's equipped insignia (nameplate badge)"
			),
			portrait_frame = DataTypes.field(
				"material",
				"[string|table|nil] the player's equipped portrait frame, empty in the middle -- "
					.. "layer it over anything, or just bind `portrait` instead, which already draws "
					.. "the portrait inside this frame"
			),
			portrait = DataTypes.field(
				"material",
				"[table|nil] the player's rendered character portrait, inside their equipped frame. "
					.. "Rendered on demand: for the first frames after it is first read this is the "
					.. "empty frame on its own, which the finished portrait then replaces. nil while "
					.. "the slot is empty"
			),
			portrait_unframed = DataTypes.field(
				"material",
				"[table|nil] the player's rendered character portrait with NO frame around it. "
					.. "Rendered on demand like `portrait`, and nil until the render lands -- "
					.. "there is no frame to stand in for it"
			),
		},
	},
}

---@param player DL_PlayerObject | nil
---@param slot_name string
---@return table|nil
local function loadout_item(player, slot_name)
	local profile = player and Player.profile(player) or nil
	local loadout = type(profile) == "table" and profile.loadout or nil
	return type(loadout) == "table" and loadout[slot_name] or nil
end

---@param item table|nil
---@param base_material string
---@param texture_slot string
---@return string|table|nil
local function item_material(item, base_material, texture_slot)
	if type(item) ~= "table" then
		return nil
	end

	local icon_material = item.icon_material
	if type(icon_material) == "string" and icon_material ~= "" then
		return icon_material
	end

	local icon = item.icon
	if type(icon) ~= "string" or icon == "" then
		return nil
	end

	return { material = base_material, values = { [texture_slot] = icon } }
end

---@param item table|nil
---@return string|table|nil
local function frame_empty_material(item)
	local material = item_material(item, FRAME_EMPTY_BASE_MATERIAL, FRAME_TEXTURE_SLOT)
	if type(material) == "table" then
		material.values.use_placeholder_texture = 0
		return material
	end
	if type(material) == "string" then
		return { material = material, values = { use_placeholder_texture = 0 } }
	end
	return nil
end

---@param previous table|nil
---@param current table|nil
---@return boolean
local function frame_values_changed(previous, current)
	previous, current = previous or {}, current or {}
	for slot, value in pairs(current) do
		if previous[slot] ~= value then
			return true
		end
	end
	for slot in pairs(previous) do
		if current[slot] == nil then
			return true
		end
	end
	return false
end

---@param previous string|table|nil
---@param current string|table|nil
---@return string|table|nil
local function stable_material(previous, current)
	if type(previous) ~= "table" or type(current) ~= "table" then

		CompositeMaterial.release(previous)
		return current
	end
	if previous.material ~= current.material or frame_values_changed(previous.values, current.values) then
		CompositeMaterial.release(previous)
		return current
	end
	return previous
end

---@type table<table, table>
local portrait_state = setmetatable({}, { __mode = "k" })

---@type number|nil
local settled_at = nil

---@return boolean
local function settling()
	if not settled_at then
		return false
	end
	if now() >= settled_at then
		settled_at = nil
		return false
	end
	return true
end

---@param state table
local function release_portrait(state)
	if state.load_id then
		local Managers = _G.Managers
		local ui_manager = Managers and Managers.ui or nil
		if ui_manager then
			pcall(ui_manager.unload_profile_portrait, ui_manager, state.load_id)
		end
		state.load_id = nil
	end
	state.character_id = nil

	CompositeMaterial.release(state.descriptor)
	CompositeMaterial.release(state.descriptor_unframed)
	state.descriptor, state.descriptor_unframed = nil, nil
	state.render = nil
end

---@param state table
local function rebuild_descriptor(state)

	CompositeMaterial.release(state.descriptor)
	CompositeMaterial.release(state.descriptor_unframed)
	if not state.render then
		state.descriptor, state.descriptor_unframed = nil, nil
		return
	end
	local base = state.frame_material or FRAME_BASE_MATERIAL
	local values = {}

	for slot, value in pairs(state.frame_values or {}) do
		values[slot] = value
	end
	for slot, value in pairs(state.render) do
		values[slot] = value
	end
	state.descriptor = { material = base, values = values }

	local unframed_values = {}
	for slot, value in pairs(state.render) do
		unframed_values[slot] = value
	end
	state.descriptor_unframed = { material = PORTRAIT_BASE_MATERIAL, values = unframed_values }
end

---@param state table
---@param profile table
local function request_portrait(state, profile)
	local Managers = _G.Managers
	local ui_manager = Managers and Managers.ui or nil
	if not ui_manager then
		return
	end

	state.character_id = profile.character_id

	local function on_unload()

		CompositeMaterial.release(state.descriptor)
		CompositeMaterial.release(state.descriptor_unframed)
		state.descriptor, state.descriptor_unframed = nil, nil
	end

	local function on_load(grid_index, rows, columns, render_target)
		state.render = {
			texture_icon = render_target,
			rows = rows,
			columns = columns,

			grid_index = (grid_index or 1) - 1,

			use_placeholder_texture = 0,
		}
		rebuild_descriptor(state)
	end

	local ok, load_id = pcall(ui_manager.load_profile_portrait, ui_manager, profile, on_load, nil, on_unload)
	if ok then
		state.load_id = load_id
	end
end

---@param values table      the slot's values table, used as the slot's identity
---@param unframed boolean   serve the frame-less descriptor instead of the framed one
---@return table|nil
local function portrait_for(values, unframed)
	local state = portrait_state[values]
	if not state then
		return nil
	end

	if settling() then
		return nil
	end

	state.demanded_at = now()

	local profile = state.profile
	if type(profile) ~= "table" then
		return nil
	end

	if not state.load_id or state.character_id ~= profile.character_id then
		release_portrait(state)
		request_portrait(state, profile)
	end

	if unframed then

		return state.descriptor_unframed
	end

	if state.descriptor then
		return state.descriptor
	end

	return values.profile and values.profile.portrait_frame or nil
end

---@param state table
local function sweep_demand(state)
	if not state.load_id then
		return
	end
	if not state.demanded_at or now() - state.demanded_at >= DEMAND_TIMEOUT then
		release_portrait(state)
	end
end

---@param values table
---@return table
local function profile_metatable(values)
	return {
		__index = function(_, key)
			if key == "portrait" then
				return portrait_for(values, false)
			end
			if key == "portrait_unframed" then
				return portrait_for(values, true)
			end
			return nil
		end,
	}
end

---@param values table                    per-slot output table, rewritten in place
---@param player DL_PlayerObject | nil     slot occupant, or nil when the slot is empty
---@param unit Unit | nil                  the player's live unit, or nil when dead/absent
function Field.write(values, player, unit)
	local profile = values.profile or {}
	values.profile = profile

	local state = portrait_state[values]
	if not state then
		state = {}
		portrait_state[values] = state

		setmetatable(profile, profile_metatable(values))
	end

	if settling() then

		release_portrait(state)
		profile.insignia = stable_material(profile.insignia, nil)
		profile.portrait_frame = stable_material(profile.portrait_frame, nil)
		state.frame_material, state.frame_values = nil, nil
		return
	end

	local frame_item = loadout_item(player, "slot_portrait_frame")

	local insignia = item_material(loadout_item(player, "slot_insignia"), INSIGNIA_BASE_MATERIAL, INSIGNIA_TEXTURE_SLOT)
	profile.insignia = stable_material(profile.insignia, insignia)

	profile.portrait_frame = stable_material(profile.portrait_frame, frame_empty_material(frame_item))

	local frame_material = item_material(frame_item, FRAME_BASE_MATERIAL, FRAME_TEXTURE_SLOT)
	local portrait_base, portrait_frame_values = FRAME_BASE_MATERIAL, nil
	if type(frame_material) == "string" then
		portrait_base = frame_material
	elseif type(frame_material) == "table" then

		portrait_base = frame_material.material
		portrait_frame_values = frame_material.values
	end

	if state.frame_material ~= portrait_base or frame_values_changed(state.frame_values, portrait_frame_values) then
		state.frame_material = portrait_base
		state.frame_values = portrait_frame_values

		rebuild_descriptor(state)
	end

	state.profile = player and Player.profile(player) or nil

	if not state.profile then

		release_portrait(state)
		return
	end

	sweep_demand(state)
end

function Field.release_all()
	settled_at = now() + STATE_SETTLE_SECONDS
	for values, state in pairs(portrait_state) do
		release_portrait(state)
		state.frame_material, state.frame_values = nil, nil
		state.profile, state.demanded_at = nil, nil
		local profile = values.profile
		if type(profile) == "table" then
			CompositeMaterial.release(profile.insignia)
			CompositeMaterial.release(profile.portrait_frame)
			profile.insignia, profile.portrait_frame = nil, nil
		end
	end
end

mod.hud_studio_player_appearance = Field
return Field
