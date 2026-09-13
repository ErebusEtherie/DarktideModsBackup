---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_composite_material then
	return mod.hud_studio_composite_material
end

local UIRenderer = require("scripts/managers/ui/ui_renderer")

local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")

local materials_by_renderer = setmetatable({}, { __mode = "k" })

---@param ui_renderer table
---@param material userdata
local function destroy_material(ui_renderer, material)
	pcall(UIRenderer.destroy_material, ui_renderer, material, false)
end

---@class CompositeMaterial
local CompositeMaterial = {}

---@param value any
---@return boolean
function CompositeMaterial.is_descriptor(value)
	return type(value) == "table" and type(value.material) == "string" and value.material ~= ""
end

---@param value any
---@return string|nil
function CompositeMaterial.base(value)
	if CompositeMaterial.is_descriptor(value) then
		return value.material
	end
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

---@param material userdata
---@param slot string
---@param value string
local function set_texture_value(material, slot, value)
	if value == "" then
		Material.set_texture(material, slot, nil)
		return
	end
	local status = MaterialDeps.require(value)
	if status == "ready" or status == "unmapped" then
		Material.set_texture(material, slot, value)
	end
end

---@param material userdata
---@param slot string
---@param value any
local function set_value(material, slot, value)
	local value_type = type(value)
	if value_type == "string" then
		set_texture_value(material, slot, value)
	elseif value_type == "number" then
		Material.set_scalar(material, slot, value)
	elseif value_type == "userdata" then

		Material.set_resource(material, slot, value)
	elseif value_type == "table" then
		local count = #value
		if count == 1 then
			Material.set_scalar(material, slot, value[1])
		elseif count == 2 then
			Material.set_vector2(material, slot, Vector2(value[1], value[2]))
		elseif count == 3 then
			Material.set_vector3(material, slot, Vector3.from_array(value))
		elseif count == 4 then
			Material.set_vector4(material, slot, Quaternion.from_elements(value[1], value[2], value[3], value[4]))
		end
	end
end

---@param material userdata
---@param slot string
---@param value any
local function apply_value(material, slot, value)
	pcall(set_value, material, slot, value)
end

---@param ui_renderer table
---@param descriptor table
---@return userdata|nil
function CompositeMaterial.resolve(ui_renderer, descriptor)
	if not ui_renderer or not CompositeMaterial.is_descriptor(descriptor) then
		return nil
	end

	local base_path = descriptor.material
	local materials = materials_by_renderer[ui_renderer]
	if not materials then
		materials = setmetatable({}, { __mode = "k" })
		materials_by_renderer[ui_renderer] = materials
	end

	local entry = materials[descriptor]
	if not entry or entry.base ~= base_path then

		if entry then
			destroy_material(ui_renderer, entry.material)
			materials[descriptor] = nil
		end
		local created_ok, created = pcall(UIRenderer.create_material, ui_renderer, base_path, false)
		if not created_ok or not created then
			return nil
		end
		entry = { base = base_path, material = created }
		materials[descriptor] = entry
	end
	local material = entry.material

	local values = descriptor.values
	if type(values) == "table" then
		for slot, value in pairs(values) do
			apply_value(material, slot, value)
		end
	end

	return material
end

---@param descriptor table|nil
function CompositeMaterial.release(descriptor)
	if type(descriptor) ~= "table" then
		return
	end
	for ui_renderer, materials in pairs(materials_by_renderer) do
		local entry = materials[descriptor]
		if entry then
			destroy_material(ui_renderer, entry.material)
			materials[descriptor] = nil
		end
	end
end

---@param ui_renderer table|nil
---@return integer destroyed
function CompositeMaterial.release_renderer(ui_renderer)
	local materials = ui_renderer and materials_by_renderer[ui_renderer]
	if not materials then
		return 0
	end
	local destroyed = 0
	for descriptor, entry in pairs(materials) do
		destroy_material(ui_renderer, entry.material)
		materials[descriptor] = nil
		destroyed = destroyed + 1
	end
	materials_by_renderer[ui_renderer] = nil
	return destroyed
end

---@return integer destroyed
function CompositeMaterial.release_all()
	local destroyed = 0
	for ui_renderer in pairs(materials_by_renderer) do
		destroyed = destroyed + CompositeMaterial.release_renderer(ui_renderer)
	end
	return destroyed
end

mod.hud_studio_composite_material = CompositeMaterial
return CompositeMaterial
