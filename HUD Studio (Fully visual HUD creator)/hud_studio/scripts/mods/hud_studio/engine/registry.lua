---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_source_registry then
	return mod.hud_studio_source_registry
end

local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

---@alias SourceKind "pull"|"event"

---@class Source : EditorDoc
---@field id string                       key code binds by, and the accessor key (e.g. "health")
---@field kind SourceKind              "pull" reads state each frame; "event" subscribes + accumulates
---@field category string?                top-level grouping for the editor's cascading dropdown (e.g. "player")
---@field label string?                   human name for the dropdown / palette
---@field fields table<string, FieldShape|table<string, FieldShape>>?   field name -> leaf shape (DataTypes.field) or a grouped field's leaf table; the dropdown's leaf level and the code palette
---@field sections { id: string, label: string }[]?   ordered headings for the Field dropdown; they head the LEAVES INSIDE a group (never the top level), and a leaf with no section lists first, unheaded
---@field field_meta table<string, {label: string?, section: string?}>?   per-field dropdown overrides keyed by field path, "group.leaf" for the leaves a section can order (label: shown instead of the localized key; section: which heading it sits under). Validated against `fields` at register.
---@field example string?                 example expression, for the code palette
---@field setup fun(bus: any)?            event sources: subscribe here (mission start)
---@field teardown fun()?                 event sources: unsubscribe here (mission end)
---@field resolve fun(ctx: Context): table  produce this source's value table (fields -> values)

---@class SourceRegistry
local Registry = {}

---@type table<string, Source>
local sources = {}

local resolved = {}
local resolved_frame = -1
---@type Context?
local current_ctx = nil

---@param source Source
function Registry.register(source)
	DataTypes.validate_fields(source.id, source.fields, source.field_meta, source.sections)
	sources[source.id] = source
end

---@param id string
---@return Source?
function Registry.get(id)
	return sources[id]
end

---@return table<string, Source>
function Registry.all()
	return sources
end

---@param frame_id number
---@param ctx Context
function Registry.begin_frame(frame_id, ctx)

	ctx.frame_id = frame_id
	current_ctx = ctx
	if frame_id ~= resolved_frame then
		resolved_frame = frame_id
		resolved = {}
	end
end

---@param id string
---@return table? values
function Registry.resolve(id)
	local hit = resolved[id]
	if hit ~= nil then
		return hit
	end

	local source = sources[id]
	if not source or not current_ctx then
		return nil
	end

	local values = source.resolve(current_ctx)
	resolved[id] = values
	return values
end

---@param id string
---@param field string
---@return any
function Registry.resolve_field(id, field)
	local value = Registry.resolve(id)
	if not value then
		return nil
	end
	if not string.find(field, ".", 1, true) then
		return value[field]
	end
	for segment in string.gmatch(field, "[^.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[segment]
	end
	return value
end

---@param field string
---@return string|string[]|nil
function Registry.compile_field(field)
	if type(field) ~= "string" then
		return nil
	end
	if not string.find(field, ".", 1, true) then
		return field
	end
	local segments = {}
	for segment in string.gmatch(field, "[^.]+") do
		segments[#segments + 1] = segment
	end
	return segments
end

---@param id string
---@param compiled string|string[]|nil
---@return any
function Registry.resolve_compiled(id, compiled)
	if compiled == nil then
		return nil
	end
	local value = Registry.resolve(id)
	if value == nil then
		return nil
	end
	if type(compiled) == "string" then
		return value[compiled]
	end
	for i = 1, #compiled do
		if type(value) ~= "table" then
			return nil
		end
		value = value[compiled[i]]
		if value == nil then
			return nil
		end
	end
	return value
end

---@return table<string, Source[]>
function Registry.by_category()
	local grouped = {}
	for _, source in pairs(sources) do
		local category = source.category or "misc"
		grouped[category] = grouped[category] or {}
		grouped[category][#grouped[category] + 1] = source
	end
	return grouped
end

mod.hud_studio_source_registry = Registry

return Registry
