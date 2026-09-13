---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_schema then
	return mod.hud_studio_schema
end

local CURRENT_VERSION = 1

---@class Index : EditorDoc
---@field version integer
---@field blocks string[]                     active block names, draw order == Z

---@class CanvasData : EditorDoc
---@field version integer
---@field grid_rows integer                   canvas grid row count (0 == none)
---@field grid_cols integer                   canvas grid column count (0 == none)
---@field vanilla table<string, boolean>?     vanilla-HUD element toggles keyed by element id; false == that

---@field hide_hidden_in_editor boolean?      true == blocks that resolve hidden are left off the editor

---@field buffs_offset number[]?             opt-in { x, y } design-px nudge applied to the vanilla buff

---@field folders table<string, FolderData>?  Folders, keyed by name. A key existing IS the

---@class FolderData : EditorDoc
---@field visible boolean?     false == every member block is forced hidden. Absent == visible.
---@field collapsed boolean?   editor-only: member rows folded away. Absent == expanded.
---@field index integer?       the folder's place in the tree, ascending from the top.

---@class BlockOrigin
---@field mod string        the registering mod's id (the owning mod may since have been uninstalled)
---@field file string       the entry's relpath inside that mod's folder, no extension
---@field version integer   the entry version this copy was taken at
---@field requires string[]? other mod ids this block's bindings reach into, as the author declared them.

---@class BlockData : EditorDoc
---@field version integer
---@field name string                         identity AND filename; safe slug, unique
---@field label string?                       optional display label (name is canonical)
---@field offset number[]                     { x, y } from screen center, 1080p px
---@field nodes Node[]                      array order == Z order
---@field visible Binding?                  block-level visibility; nil == visible (default true)
---@field scale Binding?                      block-level zoom multiplier, applied to every node's offset and geometry about the block's own origin
---@field transition TransitionData?          block-level fade in/out; nil == instant
---@field script { body: string? }?         block script: code run once per frame before the block's

---@field gamemodes table<string, boolean>?    allowed gamemodes set (nil == all); { mission?, mourningstar?, meatgrinder? }
---@field classes table<string, boolean>?      allowed archetype-id set (nil == all)
---@field players table<string, table<string, boolean>>?  player-state quick filter, keyed by party slot

---@field grid_rows integer?                   own grid row count, drawn inside the block (0/nil == none)
---@field grid_cols integer?                   own grid column count, drawn inside the block (0/nil == none)
---@field folder string?                       folder membership; absent == root (in no folder).

---@field origin BlockOrigin?                  provenance: present iff this block was inserted from a

---@field requires string[]?                   mod ids this block's bindings reach into, as the author declared them.

---@field summary string?                     author's one-line description of what the block does

---@field mod_version integer?                 the AUTHOR's content version, bumped when they ship a

---@field tags string[]?                       library categories this block files itself under
---@field export_mod string?                   the mod id this block was last exported into

---@field trashed_from string?                 where a TRASHED block came from

---@field deleted_nodes Node[]?                the block's own node bin

---@field localizations table<string, table>? embedded loc: key -> { en = "...", ... }

---@class Binding : EditorDoc
---@field kind "fixed"|"source"|"code"|"thresholds"|"conditions"|"off"|"patch"
---@field on boolean?                         visible field: the eye override (nil = auto)
---@field conditions ConditionSpec?           conditions kind: the rule list + linger/delay
---@field source string?                      source kind: source id
---@field field string?                       source kind: field within the source
---@field body string?                        code kind: the stored expression body
---@field value any?                          nested binding, fixed kind: the static value
---@field thresholds ThresholdSpec?           thresholds kind: the bands + their current/max

---@class ThresholdSpec : EditorDoc
---@field list ThresholdEntry[]
---@field scale "percent"|"number"|"boolean"|nil   nil reads as "percent"
---@field current Binding?
---@field max Binding?

---@class ThresholdEntry : EditorDoc
---@field pct number                          the band's lower edge (a percent, or a raw value)
---@field color number[]                      { a, r, g, b }

---@class ConditionSpec : EditorDoc
---@field rows ConditionRow[]
---@field linger number?
---@field delay number?

---@class ConditionRow : EditorDoc
---@field join "and"|"or"
---@field negate boolean?
---@field lhs Binding
---@field op string                            an operator id (Conditions.OP_BY_ID)
---@field rhs Binding?
---@field rhs2 Binding?

---@class TransitionData : EditorDoc
---@field fade_in number?                     duration in seconds to fade in; nil == instant
---@field fade_out number?                    duration in seconds to fade out; nil == instant
---@field ease "linear"|"in_out"?             easing curve; nil / "linear" == linear

---@class Node : EditorDoc
---@field id string                          block-local, stable; keys the node's widget
---@field label string                       node label
---@field type string                        node-type id (indexes blocks/registry)
---@field offset number[]                    { x, y } from the block
---@field style table<string, any>           static base style (reset target each frame); style.visible == false hides the node (default true). style.transition is a TransitionData for fade in/out. Text node: style.align ("left"|"center"|"right", default left) is the horizontal alignment/grow direction.
---@field values table<string, any>          static fallback values. The text node also stores its value-mode here: values.value_mode ("single"|"chain"); Chain adds per-segment slots text<i>/loc_id<i>/mode<i> (i 2..10), each mirroring the base text/loc_id/mode; each segment also gets its own rounding knob in style (style.decimals for segment 1, style.decimals<i> after it). See blocks/node_types/text.
---@field callbacks NodeCallbacks?        per-slot bindings
---@field players table<string, table<string, boolean>>?  player-state quick filter, keyed by party slot

---@class NodeCallbacks : EditorDoc
---@field value table<string, Binding>?
---@field style Binding?

---@class Schema
local Schema = {}

Schema.CURRENT_VERSION = CURRENT_VERSION

Schema.TRASH_FOLDER = "deleted_items_folder"

---@param name any
---@return boolean
function Schema.is_valid_name(name)
	return type(name) == "string" and name ~= "" and string.match(name, "^[%w_%-]+$") ~= nil
end

---@param path any
---@return boolean
function Schema.is_valid_relpath(path)
	if type(path) ~= "string" or path == "" then
		return false
	end
	if path:find("\\", 1, true) or path:find("//", 1, true) or path:sub(1, 1) == "/" or path:sub(-1) == "/" then
		return false
	end
	for segment in path:gmatch("[^/]+") do
		if not Schema.is_valid_name(segment) then
			return false 
		end
	end
	return true
end

---@param name any
---@return boolean
function Schema.is_valid_folder_name(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	if name:find("/", 1, true) or name == Schema.TRASH_FOLDER then
		return false
	end
	return name:match("^%s") == nil and name:match("%s$") == nil
end

---@param label any
---@return string
function Schema.slugify(label)
	local slug = tostring(label or "")
	slug = slug:gsub("^%s+", ""):gsub("%s+$", "") 
	slug = slug:gsub("%s+", "_") 
	slug = slug:gsub("[^%w_%-]", "") 
	return slug
end

---@param name string
---@return BlockData
function Schema.empty_block(name)
	return {
		version = CURRENT_VERSION,
		name = name,
		offset = { 0, 0 },
		nodes = {},
		grid_rows = 0,
		grid_cols = 0,
		localizations = {},
	}
end

---@return Index
function Schema.empty_index()
	return {
		version = CURRENT_VERSION,
		blocks = {},
	}
end

---@return CanvasData
function Schema.empty_canvas()
	return {
		version = CURRENT_VERSION,
		grid_rows = 0,
		grid_cols = 0,
		folders = {},
	}
end

---@param block any
---@return boolean ok
---@return string? reason
function Schema.validate_block(block)
	if type(block) ~= "table" then
		return false, "block is not a table"
	end
	if type(block.version) ~= "number" then
		return false, "missing version"
	end
	if not Schema.is_valid_name(block.name) then
		return false, "block name is missing or not a safe slug"
	end
	if type(block.nodes) ~= "table" then
		return false, "missing nodes list"
	end

	if block.scale ~= nil and type(block.scale) ~= "table" then
		return false, "scale is not a binding table"
	end
	if block.grid_rows ~= nil and type(block.grid_rows) ~= "number" then
		return false, "grid_rows is not a number"
	end
	if block.grid_cols ~= nil and type(block.grid_cols) ~= "number" then
		return false, "grid_cols is not a number"
	end
	if block.gamemodes ~= nil and type(block.gamemodes) ~= "table" then
		return false, "gamemodes is not a table"
	end
	if block.classes ~= nil and type(block.classes) ~= "table" then
		return false, "classes is not a table"
	end
	if block.players ~= nil and type(block.players) ~= "table" then
		return false, "players is not a table"
	end
	if block.requires ~= nil and type(block.requires) ~= "table" then
		return false, "requires is not a list"
	end

	if block.summary ~= nil and type(block.summary) ~= "string" then
		return false, "summary is not a string"
	end
	if block.mod_version ~= nil and type(block.mod_version) ~= "number" then
		return false, "mod_version is not a number"
	end
	if block.tags ~= nil and type(block.tags) ~= "table" then
		return false, "tags is not a list"
	end
	if block.export_mod ~= nil and type(block.export_mod) ~= "string" then
		return false, "export_mod is not a string"
	end
	if block.folder ~= nil and type(block.folder) ~= "string" then
		return false, "folder is not a string"
	end
	if block.trashed_from ~= nil and type(block.trashed_from) ~= "string" then
		return false, "trashed_from is not a string"
	end

	if block.deleted_nodes ~= nil and type(block.deleted_nodes) ~= "table" then
		return false, "deleted_nodes is not a table"
	end
	for i = 1, #block.nodes do
		local node = block.nodes[i]
		if type(node) ~= "table" or type(node.id) ~= "string" then
			return false, "node " .. i .. " has no id"
		end
		if type(node.type) ~= "string" then
			return false, "node " .. i .. " has no type"
		end
	end
	return true
end

---@param idx any
---@return boolean ok
---@return string? reason
function Schema.validate_index(idx)
	if type(idx) ~= "table" or type(idx.blocks) ~= "table" then
		return false, "index has no blocks list"
	end
	for i = 1, #idx.blocks do
		if not Schema.is_valid_name(idx.blocks[i]) then
			return false, "index entry " .. i .. " is not a safe name"
		end
	end
	return true
end

---@param canvas any
---@return boolean ok
---@return string? reason
function Schema.validate_canvas(canvas)
	if type(canvas) ~= "table" then
		return false, "canvas is not a table"
	end
	if canvas.grid_rows ~= nil and type(canvas.grid_rows) ~= "number" then
		return false, "grid_rows is not a number"
	end
	if canvas.grid_cols ~= nil and type(canvas.grid_cols) ~= "number" then
		return false, "grid_cols is not a number"
	end
	if canvas.vanilla ~= nil and type(canvas.vanilla) ~= "table" then
		return false, "vanilla is not a table"
	end
	if canvas.hide_hidden_in_editor ~= nil and type(canvas.hide_hidden_in_editor) ~= "boolean" then
		return false, "hide_hidden_in_editor is not a boolean"
	end
	local buffs_offset = canvas.buffs_offset
	if buffs_offset ~= nil then
		if type(buffs_offset) ~= "table" or type(buffs_offset[1]) ~= "number" or type(buffs_offset[2]) ~= "number" then
			return false, "buffs_offset is not an { x, y } number pair"
		end
	end
	if canvas.folders ~= nil and type(canvas.folders) ~= "table" then
		return false, "folders is not a table"
	end
	return true
end

---@param raw any
---@return table<string, FolderData>
function Schema.sanitize_folders(raw)
	local out = {}
	if type(raw) ~= "table" then
		return out
	end
	for name, rec in pairs(raw) do
		if type(name) == "string" and name ~= "" and type(rec) == "table" then
			local clean = {}

			if rec.visible == false then
				clean.visible = false
			end
			if rec.collapsed == true then
				clean.collapsed = true
			end
			if type(rec.index) == "number" then
				clean.index = math.floor(rec.index)
			end
			out[name] = clean
		end
	end
	return out
end

---@param raw any
---@return Node[]?
function Schema.sanitize_deleted_nodes(raw)
	if type(raw) ~= "table" then
		return nil
	end
	local out = {}
	for i = 1, #raw do
		local node = raw[i]
		if type(node) == "table" and type(node.id) == "string" and type(node.type) == "string" then
			out[#out + 1] = node
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end

---@param block BlockData
---@return BlockData
function Schema.migrate_block(block)
	return block
end

mod.hud_studio_schema = Schema

return Schema
