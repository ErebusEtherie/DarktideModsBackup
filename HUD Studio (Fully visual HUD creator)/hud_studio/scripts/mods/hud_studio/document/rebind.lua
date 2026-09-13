---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_rebind then
	return mod.hud_studio_rebind
end

local Registry = mod:core(mod.hud_studio_source_registry, "engine/registry")

---@class Rebind
local Rebind = {}

---@param binding Binding|nil
---@param visit fun(binding: Binding)
local function walk(binding, visit)
	if type(binding) ~= "table" then
		return
	end
	visit(binding)

	local thresholds = binding.thresholds
	if thresholds then
		walk(thresholds.current, visit)
		walk(thresholds.max, visit)
	end

	local conditions = binding.conditions
	if conditions and conditions.rows then
		local rows = conditions.rows
		for i = 1, #rows do
			walk(rows[i].lhs, visit)
			walk(rows[i].rhs, visit)
			walk(rows[i].rhs2, visit)
		end
	end
end

---@param block Block
---@param visit fun(binding: Binding)
local function each_binding(block, visit)
	walk(block.visible, visit)

	local nodes = block.nodes or {}
	for i = 1, #nodes do
		local callbacks = nodes[i].callbacks
		if callbacks then
			walk(callbacks.style, visit)
			if callbacks.value then
				for _, binding in pairs(callbacks.value) do
					walk(binding, visit)
				end
			end
		end
	end
end

---@param source_id string
---@param field string|nil
---@return boolean
local function has_field(source_id, field)
	if not field then
		return true
	end
	local source = Registry.get(source_id)
	local shape = source and source.fields
	if not shape then
		return false
	end
	for segment in string.gmatch(field, "[^.]+") do
		if type(shape) ~= "table" then
			return false
		end
		shape = shape[segment]
		if shape == nil then
			return false
		end
	end
	return true
end

---@param body string
---@param from string
---@param to string
---@return string body, integer replacements
local function rewrite_body(body, from, to)
	return string.gsub(body, "%f[%w_]" .. from .. "%f[^%w_]", to)
end

---@param block Block
---@return string[]
function Rebind.sources_used(block)
	local seen, ids = {}, {}
	each_binding(block, function(binding)
		local id = binding.source
		if id and not seen[id] then
			seen[id] = true
			ids[#ids + 1] = id
		end
	end)
	table.sort(ids)
	return ids
end

---@param block Block
---@param from string|nil
---@param to string|nil
---@param include_code boolean|nil     also rewrite `from` inside code bodies
---@param dry_run boolean|nil
---@return integer changed              bindings repointed
---@return integer skipped              bindings left alone (the new source lacks their field)
---@return integer code                 code bodies rewritten
function Rebind.run(block, from, to, include_code, dry_run)
	local changed, skipped, code = 0, 0, 0
	if not (block and from and to) or from == to then
		return changed, skipped, code
	end

	each_binding(block, function(binding)
		if binding.source == from then
			if has_field(to, binding.field) then
				changed = changed + 1
				if not dry_run then
					binding.source = to
				end
			else
				skipped = skipped + 1
			end
		end

		if include_code and type(binding.body) == "string" then
			local body, n = rewrite_body(binding.body, from, to)
			if n > 0 then
				code = code + 1
				if not dry_run then
					binding.body = body
				end
			end
		end
	end)

	return changed, skipped, code
end

mod.hud_studio_rebind = Rebind

return Rebind
