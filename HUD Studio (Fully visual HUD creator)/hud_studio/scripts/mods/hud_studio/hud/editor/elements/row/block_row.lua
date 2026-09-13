
local mod = get_mod("hud_studio")

if mod.block_row_component then
	return mod.block_row_component
end

local Row = mod:core(mod.row_component, "hud/editor/elements/row/row")
local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
local Session = mod:core(mod.hud_studio_session, "document/session")
local BlockLibrary = mod:core(mod.hud_studio_block_library, "document/block_library")

local Block = {}

local hidden_chip_ids = setmetatable({}, { __mode = "k" })
local mod_chip_ids = setmetatable({}, { __mode = "k" })

local function chip_id(store, block)
	local id = store[block]
	if not id then
		id = {}
		store[block] = id
	end
	return id
end

local mod_tooltips = setmetatable({}, { __mode = "k" })

local function mod_tooltip(block, origin)
	local cached = mod_tooltips[block]
	if cached then
		return cached
	end
	local info = BlockLibrary.owner_info(origin.mod)
	local text
	if not info.installed then
		text = mod:localize("block_row_mod_chip_owner_missing", info.label)
	elseif info.author and info.author ~= "" then
		text = mod:localize("block_row_mod_chip_owner_by", info.label, info.author)
	else
		text = mod:localize("block_row_mod_chip_owner", info.label)
	end
	local tooltip = text .. " " .. mod:localize("block_row_mod_chip_tooltip")
	mod_tooltips[block] = tooltip
	return tooltip
end

function Block.draw(
	d,
	block,
	x,
	row_y,
	w,
	z,
	selected,
	hovered,
	on_toggle,
	on_set_state,
	collapsed,
	editing,
	script_error,
	hide_hidden,
	is_hidden,
	indent,
	last
)
	Row.draw(d, x, row_y, w, z, {
		label = Block.label(block),
		caret = { open = not collapsed },
		selected = selected,
		hovered = hovered,
		editing = editing,
		indent = indent,

		tree = (indent and indent > 0) and { last = last or false } or nil,

		chips = Block.chips(block, hide_hidden, is_hidden),
		eye = {
			id = block,
			is_block = true,
			dynamic = Visibility.block_is_dynamic(block),
			on = Visibility.block_shown(block),
			state = Visibility.block_eye_state(block),
			on_toggle = on_toggle,
			on_set_state = on_set_state,
			error = script_error,
		},
	})
end

local CHIP_COLORS = {
	MOD = { 255, 255, 200, 255 },
	HIDDEN = { 255, 250, 190, 90 },
}

function Block.chips(block, hide_hidden, is_hidden)
	local origin = Session.is_mod_block(block) and block.origin or nil
	if not origin and not hide_hidden then
		return nil
	end

	local chips = {}
	if origin then
		chips[#chips + 1] = {
			id = chip_id(mod_chip_ids, block),
			text = mod:localize("block_row_mod_chip_text"),
			tooltip = mod_tooltip(block, origin),
			show = true,
			color = CHIP_COLORS.MOD,
		}
	end

	if hide_hidden or origin then
		chips[#chips + 1] = {
			id = chip_id(hidden_chip_ids, block),
			text = mod:localize("block_row_hidden_chip_text"),
			tooltip = mod:localize("block_row_hidden_chip_tooltip"),
			show = is_hidden and true or false,
			color = CHIP_COLORS.HIDDEN,
		}
	end
	return chips
end

function Block.label(block)
	if not block then
		return "?"
	end
	if block.label and block.label ~= "" then
		return block.label
	end
	if block.name and block.name ~= "" then
		return block.name
	end
	return "?"
end

mod.block_row_component = Block

return Block
