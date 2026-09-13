---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_data_types then
	return mod.hud_studio_data_types
end

---@alias DataType "number"|"integer"|"string"|"material"|"boolean"|"rgba"

---@class FieldShape : EditorDoc
---@field type DataType       the primitive the editor filters + binds on
---@field note string|nil        developer-facing description (currently unshown)

local DataTypes = {}

local VALID = {
	number = true, 
	integer = true, 
	string = true,

	material = true,
	boolean = true,

	rgba = true,
}
DataTypes.VALID = VALID

---@param type DataType
---@param note string|nil
---@return FieldShape
function DataTypes.field(type, note)
	if not VALID[type] then
		mod.dl.log.error("hud_studio data source declared unknown field type '%s' (note: %s)", tostring(type), tostring(note))
	end
	return { type = type, note = note }
end

---@param v any
---@return boolean
function DataTypes.is_leaf(v)
	return type(v) == "table" and v.type ~= nil
end

---@param shape any
---@return DataType|nil
function DataTypes.type_of(shape)
	if DataTypes.is_leaf(shape) then
		return shape.type
	end
	return nil
end

---@param id string
---@param fields table<string, any>|nil
---@param field_meta table<string, {label: string?, section: string?}>|nil
---@param sections { id: string, label: string }[]|nil
function DataTypes.validate_fields(id, fields, field_meta, sections)
	if not fields then
		return
	end
	local declared_section = {}
	for i = 1, (sections and #sections or 0) do
		declared_section[sections[i].id] = true
	end
	for path, meta in pairs(field_meta or {}) do
		if meta.section and not declared_section[meta.section] then
			mod.dl.log.error(
				"source '%s' field_meta '%s' names section '%s', which no provider declares",
				id,
				path,
				tostring(meta.section)
			)
		end
		local group, leaf = path:match("^([^.]+)%.(.+)$")
		local target = group and (type(fields[group]) == "table" and fields[group][leaf]) or fields[path]
		if target == nil then
			mod.dl.log.error("source '%s' field_meta key '%s' names no field", id, path)
		end
	end
	for name, shape in pairs(fields) do
		if DataTypes.is_leaf(shape) then

		elseif type(shape) == "table" then

			for leaf_name, leaf in pairs(shape) do
				if not DataTypes.is_leaf(leaf) then
					mod.dl.log.error(
						"source '%s' field '%s.%s' is not a declared type -- use DataTypes.field(...)",
						id,
						name,
						leaf_name
					)
				end
			end
		else
			mod.dl.log.error("source '%s' field '%s' is not a declared type -- use DataTypes.field(...)", id, name)
		end
	end
end

mod.hud_studio_data_types = DataTypes
return DataTypes
