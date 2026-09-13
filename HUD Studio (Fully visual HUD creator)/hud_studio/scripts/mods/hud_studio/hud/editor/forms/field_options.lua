
local mod = get_mod("hud_studio")

if mod.hud_studio_field_options then
	return mod.hud_studio_field_options
end

local Registry = mod:core(mod.hud_studio_source_registry, "engine/registry")
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

local FieldOptions = {}

function FieldOptions.is_group(hint)
	return type(hint) == "table" and not DataTypes.is_leaf(hint)
end

function FieldOptions.label(source, path)
	local meta = source and source.field_meta and source.field_meta[path]
	if meta and meta.label then
		return meta.label
	end
	return mod:localize(path:match("([^.]+)$") or path)
end

local function group_leaves(source, group_name, shape, accept)
	local names = {}
	for name, hint in pairs(shape) do
		if accept(hint) then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b)
		return FieldOptions.label(source, group_name .. "." .. a) < FieldOptions.label(source, group_name .. "." .. b)
	end)
	return names
end

local function leaf_row(source, group_name, leaf)
	local path = group_name .. "." .. leaf
	return { value = path, text = FieldOptions.label(source, path), child = true }
end

local function group_rows(source, group_name, shape, accept)
	local leaves = group_leaves(source, group_name, shape, accept)
	local field_meta = source.field_meta
	local sections = source.sections

	local declared = {}
	for i = 1, (sections and #sections or 0) do
		declared[sections[i].id] = true
	end

	local buckets = {}
	for i = 1, #leaves do
		local meta = field_meta and field_meta[group_name .. "." .. leaves[i]]
		local id = meta and meta.section or ""
		if not declared[id] then
			id = ""
		end
		buckets[id] = buckets[id] or {}
		local bucket = buckets[id]
		bucket[#bucket + 1] = leaves[i]
	end

	local order = { { id = "" } }
	local sections = source.sections
	for i = 1, (sections and #sections or 0) do
		order[#order + 1] = sections[i]
	end

	local rows = {}
	for i = 1, #order do
		local section = order[i]
		local bucket = buckets[section.id]
		if bucket then
			if section.id ~= "" then
				rows[#rows + 1] = { text = section.label or section.id, section = true, child = true }
			end
			for b = 1, #bucket do
				rows[#rows + 1] = leaf_row(source, group_name, bucket[b])
			end
		end
	end
	return rows
end

function FieldOptions.build(source_id, accept)
	local source = source_id and Registry.get(source_id)
	local out = {}
	if not (source and source.fields) then
		return out
	end

	local names = {}
	for name in pairs(source.fields) do
		names[#names + 1] = name
	end
	table.sort(names, function(a, b)
		return FieldOptions.label(source, a) < FieldOptions.label(source, b)
	end)

	for n = 1, #names do
		local name = names[n]
		local hint = source.fields[name]
		if FieldOptions.is_group(hint) then
			local rows = group_rows(source, name, hint, accept)
			if #rows > 0 then
				out[#out + 1] = { value = name, text = FieldOptions.label(source, name), group = true }
				for r = 1, #rows do
					out[#out + 1] = rows[r]
				end
			end
		elseif accept(hint) then
			out[#out + 1] = { value = name, text = FieldOptions.label(source, name) }
		end
	end
	return out
end

function FieldOptions.any(source, accept)
	if not (source and source.fields) then
		return false
	end
	for _, hint in pairs(source.fields) do
		if FieldOptions.is_group(hint) then
			for _, leaf in pairs(hint) do
				if accept(leaf) then
					return true
				end
			end
		elseif accept(hint) then
			return true
		end
	end
	return false
end

mod.hud_studio_field_options = FieldOptions

return FieldOptions
