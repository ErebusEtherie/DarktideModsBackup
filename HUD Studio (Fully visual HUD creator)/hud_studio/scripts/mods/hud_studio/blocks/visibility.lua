---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_visibility then
	return mod.hud_studio_visibility
end

local Conditions = mod:core(mod.hud_studio_conditions, "blocks/conditions")

local Visibility = {}

Visibility.FIELD = "visible"

Visibility.PLAYERS_FIELD = "players"

Visibility.BLOCK_SCOPE = { "sources", "state", "block", "t", "dt" }

Visibility.DEFAULT_MODE = "conditions"

Visibility.PLAYER_COUNT = 4

Visibility.PLAYER_CHECKS = {
	{ value = "alive", text = mod:localize("visibility_option_alive"), field = "state.alive" },
	{ value = "dead", text = mod:localize("visibility_option_dead"), field = "state.dead" },
	{ value = "in_party", text = mod:localize("visibility_option_in_party"), field = "state.in_party" },
}

function Visibility.player_id(slot)
	return "player_" .. slot
end

function Visibility.player_check(carrier, player_id, check_id)
	local players = carrier and carrier[Visibility.PLAYERS_FIELD]
	local row = players and players[player_id]
	return (row and row[check_id]) == true
end

local function prune_players(carrier)
	local players = carrier[Visibility.PLAYERS_FIELD]
	if not players then
		return
	end
	local any_row = false
	for player_id, row in pairs(players) do
		if next(row) == nil then
			players[player_id] = nil
		else
			any_row = true
		end
	end
	if not any_row then
		carrier[Visibility.PLAYERS_FIELD] = nil
	end
end

function Visibility.toggle_player_check(carrier, player_id, check_id)
	local players = carrier[Visibility.PLAYERS_FIELD]
	if not players then
		players = {}
		carrier[Visibility.PLAYERS_FIELD] = players
	end
	local row = players[player_id]
	if not row then
		row = {}
		players[player_id] = row
	end
	row[check_id] = (not row[check_id]) or nil
	prune_players(carrier)
end

Visibility.FILTER_FIELDS = { "gamemodes", "classes" }

function Visibility.filters_active(block)
	if not block then
		return false
	end
	local fields = Visibility.FILTER_FIELDS
	for i = 1, #fields do
		local set = block[fields[i]]
		if type(set) == "table" then
			return true
		end
	end
	return false
end

function Visibility.players_active(carrier)
	local players = carrier and carrier[Visibility.PLAYERS_FIELD]
	if not players then
		return false
	end
	for _, row in pairs(players) do
		if next(row) ~= nil then
			return true
		end
	end
	return false
end

local function mode_of(rec)
	local kind = rec and rec.kind
	if kind == "code" then
		return "code"
	elseif kind == "source" then
		return "source"
	end
	return Visibility.DEFAULT_MODE
end

local function rec_is_dynamic(rec)
	if not rec then
		return false
	end
	local mode = mode_of(rec)
	if mode == "code" then
		return type(rec.body) == "string" and rec.body:find("%S") ~= nil
	elseif mode == "source" then
		return rec.source ~= nil and rec.field ~= nil
	end
	local spec = rec.conditions
	return type(spec) == "table" and type(spec.rows) == "table" and #spec.rows > 0
end

local function eye_state_of(on, dynamic)
	if on == false then
		return "off"
	elseif on == true then
		return "on"
	end
	return dynamic and "auto" or "on"
end

function Visibility.next_eye_state(state, dynamic)
	if not dynamic then
		return state == "off" and "on" or "off"
	end
	if state == "off" then
		return "on"
	elseif state == "on" then
		return "auto"
	end
	return "off"
end

function Visibility.node_mode(node)
	local value = node.callbacks and node.callbacks.value
	return mode_of(value and value.visible)
end

local function node_rec(node)
	local value = node.callbacks and node.callbacks.value
	return value and value.visible
end

function Visibility.node_is_dynamic(node)
	return rec_is_dynamic(node_rec(node)) or Visibility.players_active(node)
end

function Visibility.node_shown(node)
	return not (node.style and node.style.visible == false)
end

function Visibility.set_node_shown(node, on)
	node.style = node.style or {}

	if on then
		node.style.visible = nil
	else
		node.style.visible = false
	end
end

function Visibility.node_eye_state(node)
	local on = node.style and node.style.visible
	return eye_state_of(on, Visibility.node_is_dynamic(node))
end

function Visibility.set_node_eye_state(node, state)
	node.style = node.style or {}
	if state == "off" then
		node.style.visible = false
	elseif state == "on" and Visibility.node_is_dynamic(node) then
		node.style.visible = true
	else
		node.style.visible = nil
	end
end

function Visibility.node_conditions(node)
	local rec = node_rec(node)
	if rec and mode_of(rec) == "conditions" then
		return rec.conditions
	end
	return nil
end

function Visibility.ensure_node_conditions(node)
	node.callbacks = node.callbacks or {}
	node.callbacks.value = node.callbacks.value or {}
	local rec = node.callbacks.value[Visibility.FIELD]
	if not rec then
		rec = {}
		node.callbacks.value[Visibility.FIELD] = rec
	end
	rec.kind = "conditions"
	return Visibility.ensure_conditions(rec)
end

function Visibility.block_mode(block)
	return mode_of(block and block.visible)
end

function Visibility.block_is_dynamic(block)
	return rec_is_dynamic(block and block.visible)
		or Visibility.players_active(block)
		or Visibility.filters_active(block)
end

function Visibility.block_shown(block)
	local rec = block and block.visible
	return not (rec and rec.on == false)
end

local function rec_has_payload(rec)
	if not rec then
		return false
	end
	if type(rec.body) == "string" and rec.body ~= "" then
		return true
	end
	if rec.source ~= nil or rec.field ~= nil then
		return true
	end
	return rec.conditions ~= nil
end

function Visibility.set_block_shown(block, on)
	local rec = block.visible
	if on then
		if rec then
			rec.on = nil
			if not rec_has_payload(rec) then
				block.visible = nil
			end
		end
	else
		rec = rec or { kind = Visibility.DEFAULT_MODE }
		rec.on = false
		block.visible = rec
	end
end

function Visibility.block_eye_state(block)
	local rec = block and block.visible
	return eye_state_of(rec and rec.on, Visibility.block_is_dynamic(block))
end

function Visibility.set_block_eye_state(block, state)
	if not Visibility.block_is_dynamic(block) then
		Visibility.set_block_shown(block, state ~= "off")
		return
	end
	local rec = block.visible or { kind = Visibility.DEFAULT_MODE }
	block.visible = rec
	if state == "off" then
		rec.on = false
	elseif state == "on" then
		rec.on = true
	else
		rec.on = nil
	end
end

function Visibility.block_conditions(block)
	local rec = block and block.visible
	if rec and mode_of(rec) == "conditions" then
		return rec.conditions
	end
	return nil
end

function Visibility.ensure_block_conditions(block)
	local rec = block.visible or {}
	rec.kind = "conditions"
	block.visible = rec
	return Visibility.ensure_conditions(rec)
end

function Visibility.ensure_conditions(rec)
	rec.conditions = Conditions.normalize(rec.conditions)
	return rec.conditions
end

function Visibility.player_checklists(carrier)
	local rows = {}
	for slot = 1, Visibility.PLAYER_COUNT do
		local player_id = Visibility.player_id(slot)
		rows[slot] = {
			kind = "checklist",
			left_label = "Player " .. slot,
			items = Visibility.PLAYER_CHECKS,
			is_on = function(check_id)
				return Visibility.player_check(carrier, player_id, check_id)
			end,
			toggle = function(check_id)
				Visibility.toggle_player_check(carrier, player_id, check_id)
			end,
		}
	end
	return rows
end

mod.hud_studio_visibility = Visibility

return Visibility
